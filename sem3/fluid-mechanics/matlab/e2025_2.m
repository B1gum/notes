%% Cylinder Drag from Surface Pressure - Analytical Uncertainty
clear; clc; close all;

% Input Data
% Upstream Dynamic Head
h_up_mm = 44.0; 

% Surface Pressure Data
% Theta [degrees], Manometer h [mm]
theta_deg = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, ...
             190, 200, 210, 220, 230, 240, 250, 260, 270, 280, 290, 300, 310, 320, 330, 340, 350, 360];

h_surf_mm = [38, 36, 26, 10, -14, -36, -53, -70, -78, -69, -62, -47, -38, -35, -35, -34, -34, -34, -34, ...
             -34, -34, -34, -34, -35, -35, -38, -47, -62, -69, -78, -70, -53, -36, -14, 10, 26, 36];

% Convert to SI / Radians
h_up = h_up_mm / 1000;      % [m]
h_s = h_surf_mm / 1000;     % [m]
theta = deg2rad(theta_deg); % [rad]

% Calculate Cd
% Formula: Cd = 0.5 * Integral( (h_s / h_up) * cos(theta) dtheta )
Cp = h_s ./ h_up;
integrand = Cp .* cos(theta);

% Integrate using Trapezoidal Rule
integral_val = trapz(theta, integrand);
Cd = 0.5 * integral_val;

fprintf('Calculated Cd (Pressure): %.3f\n', Cd);

% Uncertainty Analysis (Analytical)
% Type B Estimates
u_h = 1.0 / 1000;   % Manometer uncertainty [m] (+/- 1 mm)

% A. Uncertainty due to Upstream Head (h_up) - COR
% h_up is in the denominator of the whole integral.
% dCd/dh_up = -Cd / h_up
sens_hup = -Cd / h_up;
u_Cd_hup = abs(sens_hup) * u_h;

% B. Uncertainty due to Surface Pressures (h_s) - UNCOR
% Each tap is independent. We use RSS (Root Sum Square).
% dCd/dh_i = (1 / 2 h_up) * weight_i * cos(theta_i)

% Calculate integration weights (d_theta)
N = length(theta);
weights = zeros(1, N);
dt = diff(theta);
% Trapezoidal weights: half interval on ends, full interval in middle
weights(1) = dt(1)/2;
weights(end) = dt(end)/2;
weights(2:end-1) = (dt(1:end-1) + dt(2:end)) / 2;

% Sensitivity for each point
sens_hs = (weights .* cos(theta)) ./ (2 * h_up);

% Combine random errors (RSS)
u_Cd_surf = sqrt(sum((sens_hs * u_h).^2));

% Total uncertainty
u_combined = sqrt(u_Cd_hup^2 + u_Cd_surf^2);
u_expanded = 2 * u_combined; % k=2 (95%)

fprintf('\n--- Uncertainty Analysis ---\n');
fprintf('Uncertainty Contributions:\n');
fprintf('  Upstream Head (h_up): %.4f (Systematic)\n', u_Cd_hup);
fprintf('  Surface Heads (h_i):  %.4f (Random RSS)\n', u_Cd_surf);
fprintf('----------------------------------------\n');
fprintf('Combined Standard Uncertainty: %.3f\n', u_combined);
fprintf('Expanded Uncertainty (95%%):     %.3f\n', u_expanded);
fprintf('\nFinal Result:\n');
fprintf('Cd (Pressure) = %.2f +/- %.2f\n', Cd, u_expanded);