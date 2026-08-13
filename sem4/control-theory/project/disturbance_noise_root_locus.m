clear; clc; close all;

s = tf('s');

%% Plant from project report: PWM -> position [degrees]
P = 16.31/(s*(s + 4.426));

%% Controller definitions
Tf = 0;

controllers(1).name = "Conservative PID";
controllers(1).Kp = 2.591;
controllers(1).Ki = 1.204;
controllers(1).Kd = 0.366;

controllers(2).name = "Aggressive PID";
controllers(2).Kp = 7.484;
controllers(2).Ki = 3.508;
controllers(2).Kd = 0.937;

%% Frequency ranges
wAll   = logspace(-2, 3, 2000);          % full analysis range
wDist  = logspace(-2, log10(2), 500);    % slow disturbances
wNoise = logspace(log10(20), 3, 500);    % high-frequency sensor noise

%% Storage
Name = strings(numel(controllers),1);
Kp = zeros(numel(controllers),1);
Ki = zeros(numel(controllers),1);
Kd = zeros(numel(controllers),1);
PM_deg = zeros(numel(controllers),1);
Wcp_rad_s = zeros(numel(controllers),1);
Ms_dB = zeros(numel(controllers),1);
Mt_dB = zeros(numel(controllers),1);
DistOutput_dB = zeros(numel(controllers),1);
DistInput_dB = zeros(numel(controllers),1);
NoiseOutput_dB = zeros(numel(controllers),1);
NoisePWM_dB = zeros(numel(controllers),1);

for i = 1:numel(controllers)

    Name(i) = controllers(i).name;
    Kp(i) = controllers(i).Kp;
    Ki(i) = controllers(i).Ki;
    Kd(i) = controllers(i).Kd;

    %% Filtered PID controller
    C = pid(Kp(i), Ki(i), Kd(i), Tf);

    %% Closed-loop sensitivity functions
    L = minreal(C*P);

    S = feedback(1, L);       % S = 1/(1 + L)
    T = feedback(L, 1);       % T = L/(1 + L)

    Gd_output = S;            % output disturbance -> output
    Gd_input  = minreal(P*S); % input/PWM disturbance -> output

    Gn_output = -T;           % sensor noise -> output
    Gn_pwm    = -minreal(C*S);% sensor noise -> controller output/PWM

    %% Classical margins
    [~, PM_deg(i), ~, Wcp_rad_s(i)] = margin(L);

    %% Peak sensitivity metrics
    [Ms_dB(i), ~] = maxMagDb(S, wAll);
    [Mt_dB(i), ~] = maxMagDb(T, wAll);

    %% Disturbance and noise metrics
    DistOutput_dB(i) = maxMagDb(Gd_output, wDist);
    DistInput_dB(i)  = maxMagDb(Gd_input,  wDist);

    NoiseOutput_dB(i) = maxMagDb(Gn_output, wNoise);
    NoisePWM_dB(i)    = maxMagDb(Gn_pwm,    wNoise);

    %% Bode plots
    figure;
    bodeplot(S, T, {1e-2, 1e3});
    grid on;
    legend("S = disturbance sensitivity", ...
           "T = sensor-noise-to-output sensitivity", ...
           "Location", "best");
    title("Sensitivity functions: " + Name(i));

    figure;
    bodeplot(Gd_input, Gn_pwm, {1e-2, 1e3});
    grid on;
    legend("P*S = input/load disturbance to output", ...
           "C*S = sensor noise to PWM/control effort", ...
           "Location", "best");
    title("Disturbance and control-noise sensitivity: " + Name(i));

    %% Optional time-domain disturbance tests
    figure;
    step(Gd_output, 2);
    grid on;
    title("Output disturbance rejection: y/d = S, " + Name(i));

    figure;
    step(Gd_input, 2);
    grid on;
    title("Input/load disturbance rejection: y/d = P*S, " + Name(i));
    
end

%% Summary table
Results = table(Name, Kp, Ki, Kd, PM_deg, Wcp_rad_s, ...
    Ms_dB, Mt_dB, DistOutput_dB, DistInput_dB, NoiseOutput_dB, NoisePWM_dB);

disp(Results);

%% Helper function
function [dbPeak, wPeak] = maxMagDb(sys, w)
    response = squeeze(freqresp(sys, w));
    mag = abs(response(:));
    [magPeak, idx] = max(mag);
    dbPeak = 20*log10(magPeak);
    wPeak = w(idx);
end

