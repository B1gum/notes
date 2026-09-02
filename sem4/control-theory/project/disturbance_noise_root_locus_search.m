clear; clc; close all;

s = tf('s');

%% Plant TF
G = 16.31/(s*(s + 4.426));

%% PID derivative filter
% Tf = 0 gives ideal PID.
% For real implementation, try something like Tf = 0.02.
Tf = 0;

%% Frequency bands
wAll   = logspace(-2, 3, 1000);
wDist  = logspace(-2, log10(2), 300);     % Disturbances are slow
wNoise = logspace(log10(20), 3, 300);     % Sensor noise is fast

%% Design specs
maxSettlingTime = 1.0;
maxOvershoot    = 20;
minPhaseMargin  = 0;
maxMs_dB        = inf;

% Convert overshoot spec to damping ratio line
zetaMin = -log(maxOvershoot/100) / sqrt(pi^2 + log(maxOvershoot/100)^2);

% Approximate settling time condition:
% Ts ≈ 4/sigma, where sigma = -real(pole)
sigmaMin = 4/maxSettlingTime;

%% Root-locus design search
% Instead of directly searching Kp, Ki, Kd,
% we search PID zero locations z1, z2 and root-locus gain Krl.

z1_values = linspace(0.2, 8, 20);
z2_values = linspace(0.2, 12, 30);

% Root locus gain values
K_values = logspace(-1, 1, 50);

% Optional: restrict controller gains to your old search range
useGainLimits = true;

Kp_limits = [1, 8];
Ki_limits = [1, 10];
Kd_limits = [0.05, 10];

varNames = ["z1", "z2", "Krl", ...
            "Kp", "Ki", "Kd", ...
            "SettlingTime", "Overshoot", ...
            "PhaseMargin", "Crossover", ...
            "DominantPoleReal", "DominantZeta", ...
            "Disturbance_dB", "OutputNoise_dB", "PWMNoise_dB", ...
            "Ms_dB", "Mt_dB"];

rows = zeros(0, numel(varNames));

for z1 = z1_values
    for z2 = z2_values

        % Avoid duplicate zero pairs
        if z2 < z1
            continue
        end

        % PID root-locus shape:
        %
        %   Gc_shape = ((s+z1)(s+z2)) / (s(Tf*s+1))
        %
        % Then the root locus gain Krl scales this whole controller.
        Cshape = ((s + z1)*(s + z2)) / (s*(Tf*s + 1));

        Lshape = Cshape*G;

        % Get root locus poles for all K_values
        rlPoles = rlocus(Lshape, K_values);

        for kIndex = 1:length(K_values)

            Krl = K_values(kIndex);
            poles = rlPoles(:, kIndex);

            %% Root-locus pole-location filtering

            % Must be stable
            if any(real(poles) >= 0)
                continue
            end

            dominantRealPart = max(real(poles));

            % Approximate settling-time filter
            if dominantRealPart > -sigmaMin
                continue
            end

            % Approximate damping-ratio filter for dominant complex poles
            dominantPoles = poles(real(poles) > dominantRealPart - 1e-6);
            dominantComplexPoles = dominantPoles(abs(imag(dominantPoles)) > 1e-6);

            if ~isempty(dominantComplexPoles)
                zetaDom = min(-real(dominantComplexPoles)./abs(dominantComplexPoles));

                if zetaDom < zetaMin
                    continue
                end
            else
                zetaDom = Inf;
            end

            %% Convert root-locus zero/gain form to MATLAB PID gains
            %
            % Desired controller:
            %
            %   Gc = Krl * (s+z1)(s+z2) / (s(Tf*s+1))
            %
            % MATLAB PID form:
            %
            %   Gc = Kp + Ki/s + Kd*s/(Tf*s+1)

            Ki = Krl*z1*z2;
            Kp = Krl*(z1 + z2) - Ki*Tf;
            Kd = Krl - Kp*Tf;

            % Reject non-physical PID values
            if Kp <= 0 || Ki <= 0 || Kd <= 0
                continue
            end

            % Optional old gain range filters
            if useGainLimits
                if Kp < Kp_limits(1) || Kp > Kp_limits(2)
                    continue
                end

                if Ki < Ki_limits(1) || Ki > Ki_limits(2)
                    continue
                end

                if Kd < Kd_limits(1) || Kd > Kd_limits(2)
                    continue
                end
            end

            %% Build actual PID controller
            Gc = pid(Kp, Ki, Kd, Tf);
            L = Gc*G;

            % Closed-loop reference transfer
            T = feedback(L, 1);

            if ~isstable(T)
                continue
            end

            info = stepinfo(T);

            %% Exact time-domain filters
            if isnan(info.SettlingTime) || info.SettlingTime > maxSettlingTime
                continue
            end

            if info.Overshoot > maxOvershoot
                continue
            end

            %% Margins
            [~, Pm, ~, Wcp] = margin(L);

            if isnan(Pm) || Pm < minPhaseMargin
                continue
            end

            %% Sensitivity functions
            S = feedback(1, L);       % 1/(1+L)
            T = feedback(L, 1);       % L/(1+L)

            % Disturbance entering before the plant
            Gd = feedback(G, Gc);     % G/(1+Gc*G)

            % Sensor noise to output
            Gn_y = -T;

            % Sensor noise to actuator/PWM
            Gn_u = -Gc*S;

            %% Frequency-domain metrics
            distTransmission = maxMag(Gd, wDist);
            outputNoise      = maxMag(Gn_y, wNoise);
            pwmNoise         = maxMag(Gn_u, wNoise);

            Ms = maxMag(S, wAll);
            Mt = maxMag(T, wAll);

            if mag2db(Ms) > maxMs_dB
                continue
            end

            rows = [rows; ...
                z1, z2, Krl, ...
                Kp, Ki, Kd, ...
                info.SettlingTime, info.Overshoot, ...
                Pm, Wcp, ...
                dominantRealPart, zetaDom, ...
                mag2db(distTransmission), ...
                mag2db(outputNoise), ...
                mag2db(pwmNoise), ...
                mag2db(Ms), mag2db(Mt)];
        end
    end
end

%% Store results
results = array2table(rows, "VariableNames", varNames);

disp("Valid root-locus PID controllers:");
disp(results);

if isempty(results)
    warning("No valid controllers found. Try wider z1/z2/K ranges or relax the specs.");
    return
end

%% Find Pareto-optimal controllers
isPareto = true(height(results), 1);

for i = 1:height(results)
    for j = 1:height(results)

        betterOrEqualDist = results.Disturbance_dB(j) <= results.Disturbance_dB(i);
        betterOrEqualNoise = results.OutputNoise_dB(j) <= results.OutputNoise_dB(i);

        strictlyBetter = results.Disturbance_dB(j) < results.Disturbance_dB(i) || ...
                         results.OutputNoise_dB(j) < results.OutputNoise_dB(i);

        if betterOrEqualDist && betterOrEqualNoise && strictlyBetter
            isPareto(i) = false;
            break
        end
    end
end

pareto = results(isPareto, :);
pareto = sortrows(pareto, "OutputNoise_dB");

disp("Pareto-optimal root-locus PID controllers:");
disp(pareto);

%% Plot all valid controllers
figure;
scatter(results.OutputNoise_dB, results.Disturbance_dB, ...
        20, results.SettlingTime, 'filled');

grid on;
xlabel('High-frequency output noise transmission, max |T| [dB]');
ylabel('Low-frequency disturbance transmission, max |G/(1+L)| [dB]');
title('Root-locus PID controllers: noise vs disturbance trade-off');

cb = colorbar;
cb.Label.String = 'Settling time [s]';

hold on;
scatter(pareto.OutputNoise_dB, pareto.Disturbance_dB, ...
        80, 'o', 'LineWidth', 1.5);

plot(pareto.OutputNoise_dB, pareto.Disturbance_dB, ...
     'LineWidth', 1.5);

legend('Valid controllers', 'Pareto controllers', 'Pareto frontier');

%% Pick a balanced Pareto candidate
% Lower disturbance, lower output noise, lower PWM noise, and faster settling are better.
score = rangeNorm(pareto.Disturbance_dB) + ...
        rangeNorm(pareto.OutputNoise_dB) + ...
        0.5*rangeNorm(pareto.PWMNoise_dB) + ...
        0.5*rangeNorm(pareto.SettlingTime);

[~, bestIndex] = min(score);
best = pareto(bestIndex, :);

disp("Selected balanced root-locus candidate:");
disp(best);

%% Plot root locus for selected zero pair
z1_best = best.z1;
z2_best = best.z2;
K_best  = best.Krl;

Cshape_best = ((s + z1_best)*(s + z2_best)) / (s*(Tf*s + 1));
Lshape_best = Cshape_best*G;

figure;
rlocus(Lshape_best, K_values);
grid on;
hold on;

% Damping ratio line
sgrid(zetaMin, []);

% Settling-time vertical line
xline(-sigmaMin, '--', 'Settling-time boundary');

% Mark selected closed-loop poles
bestPoles = rlocus(Lshape_best, K_best);
plot(real(bestPoles), imag(bestPoles), 'kx', ...
     'MarkerSize', 10, 'LineWidth', 2);

title(sprintf('Root locus for selected PID zeros: z1 = %.3g, z2 = %.3g', ...
      z1_best, z2_best));

%% Step response of selected controller
Gc_best = pid(best.Kp, best.Ki, best.Kd, Tf);
T_best = feedback(Gc_best*G, 1);

figure;
step(T_best);
grid on;
title('Step response of selected root-locus PID controller');

%% Helper functions
function m = maxMag(sys, w)
    mag = squeeze(abs(freqresp(sys, w)));
    m = max(mag);
end

function y = rangeNorm(x)
    x = double(x);
    if max(x) == min(x)
        y = zeros(size(x));
    else
        y = (x - min(x)) ./ (max(x) - min(x));
    end
end