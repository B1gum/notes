clear; clc; close all;

s = tf('s');

% Plant TF
G = 16.31/(s*(s + 4.426));

% Derivative filter time constant
Tf = 0;

% Frequency bands
wAll   = logspace(-2, 3, 1000);
wDist  = logspace(-2, log10(2), 300);     % Disturbances are slow
wNoise = logspace(log10(20), 3, 300);     % Sensor noise is fast

% Search ranges
Kp_values = linspace(1, 8, 14);
Ki_values = linspace(1, 10, 25);
Kd_values = linspace(0.05, 10, 20);

results = table();

for Kp = Kp_values
    for Ki = Ki_values
        for Kd = Kd_values

            % Filtered PID
            Gc = pid(Kp, Ki, Kd, Tf);
            L = Gc*G;

            % Closed-loop reference transfer
            T = feedback(L, 1);

            if ~isstable(T)
                continue
            end

            info = stepinfo(T);

            % Reject controllers that fail basic specs
            if isnan(info.SettlingTime) || info.SettlingTime > 1.0
                continue
            end

            if info.Overshoot > 5
                continue
            end

            % Margins
            [~, Pm, ~, Wcp] = margin(L);

            if isnan(Pm) || Pm < 40
                continue
            end

            % Sensitivity functions
            S = feedback(1, L);       % 1/(1+L)
            T = feedback(L, 1);       % L/(1+L)

            % Disturbance entering before the plant
            Gd = feedback(G, Gc);     % G/(1+Gc*G)

            % Noise to output
            Gn_y = -T;

            % Noise to actuator/PWM
            Gn_u = -Gc*S;

            % Metrics
            distTransmission = maxMag(Gd, wDist);
            outputNoise      = maxMag(Gn_y, wNoise);
            pwmNoise         = maxMag(Gn_u, wNoise);

            Ms = maxMag(S, wAll);
            Mt = maxMag(T, wAll);

            % Optional robustness filters
            if mag2db(Ms) > 6
                continue
            end

            results = [results; table( ...
                Kp, Ki, Kd, ...
                info.SettlingTime, info.Overshoot, ...
                Pm, Wcp, ...
                mag2db(distTransmission), ...
                mag2db(outputNoise), ...
                mag2db(pwmNoise), ...
                mag2db(Ms), mag2db(Mt), ...
                'VariableNames', ["Kp","Ki","Kd", ...
                "SettlingTime","Overshoot", ...
                "PhaseMargin","Crossover", ...
                "Disturbance_dB","OutputNoise_dB","PWMNoise_dB", ...
                "Ms_dB","Mt_dB"])];

        end
    end
end

disp(results);

% Find Pareto-optimal controllers
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

% Plot all valid controllers
figure;
scatter(results.OutputNoise_dB, results.Disturbance_dB, 20, results.SettlingTime, 'filled');
grid on;
xlabel('High-frequency output noise transmission, max |T| [dB]');
ylabel('Low-frequency disturbance transmission, max |G/(1+L)| [dB]');
title('Valid PID controllers: noise vs disturbance trade-off');
cb = colorbar;
cb.Label.String = 'Settling time [s]';

hold on;
scatter(pareto.OutputNoise_dB, pareto.Disturbance_dB, 80, 'o', 'LineWidth', 1.5);

% Sort Pareto points for visual connection
pareto = sortrows(pareto, "OutputNoise_dB");
plot(pareto.OutputNoise_dB, pareto.Disturbance_dB, 'LineWidth', 1.5);

legend('Valid controllers', 'Pareto controllers', 'Pareto frontier');

% Show best Pareto candidates
disp("Pareto-optimal controllers:");
disp(pareto);

function m = maxMag(sys, w)
    mag = squeeze(abs(freqresp(sys, w)));
    m = max(mag);
end