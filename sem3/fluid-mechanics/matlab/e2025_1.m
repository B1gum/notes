clear; clc; close all;

%Experimental Data
% Cylinder dimensions
D_mm = 63.5;            % Diameter
h_up_mm = 44.0;         % Upstream dynamic pressure head

% Wake velocity profile (Position, Manometer)
y_mm = [0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55, 60, 65, 70, 75, 80, 85, 90, 95, ...
         100, 105, 110, 115, 120, 125, 130, 135, 140, 145, 150, 155, 160, 165, 170, 175, ...
         180, 185, 190, 195, 200, 205, 210];

h_wake_mm = [45, 44, 45, 45, 44, 42, 41, 40, 39, 37, 35, 34, 31, 30, 28, 25, 25, 23, 21, 20, ...
          19, 19, 19, 19, 19, 19, 20, 21, 23, 25, 25, 28, 30, 31, 34, 35, 37, 39, 40, 41, ...
          42, 44, 45];

% Convert to SI
D = D_mm / 1000;         % [m]
y = y_mm / 1000;         % [m]
h_up = h_up_mm / 1000;   % [m]
h_w = h_wake_mm / 1000;  % [m]

% Type B Uncertainty estimates
u_h = 1.0 / 1000;   % Manometer reading uncertainty (+/- 1 mm)
u_D = 0.1 / 1000;   % Diameter uncertainty (+/- 0.1 mm)

% Drag Coefficient Calculation
% Velocity Ratio (u/U = sqrt(h_wake / h_up))
u_ratio = sqrt(h_w ./ h_up);

% Integrand(f = (u/U) * (1 - u/U))
integrand = u_ratio .* (1 - u_ratio);

% Integration (using trapezoidal Rule)
integral_val = trapz(y, integrand);

% Cd found as (2/D) * Integral
Cd = (2 / D) * integral_val;

fprintf('Calculated Drag Coefficient (Cd): %.3f\n', Cd);

% Analytical Uncertainty Propagation
% Cd = (2/D) * Sum( w_i * f_i * dy )
% We calculate sensitivity coefficients (derivatives) for each source.

% 1. Sensitivity to Diameter
% d(Cd)/dD = -Cd / D
sens_D = -Cd / D;
u_Cd_D = abs(sens_D) * u_D;

% 2. Sensitivity to Upstream Head (h_up)
% h_up affects every point in the profile (so it i)
% f = sqrt(h/h_up) - h/h_up
% df/dh_up = (1/2)*(h/h_up)^(-0.5)*(-h/h_up^2) - (-h/h_up^2) ??
% Simplified: let r = sqrt(h/h_up). f = r - r^2.
% dr/dh_up = -0.5 * r / h_up
% df/dh_up = (1 - 2r) * dr/dh_up = (1 - 2r) * (-0.5 * r / h_up)
r = u_ratio;
df_dhup = (1 - 2*r) .* (-0.5 * r ./ h_up);

% Integrate the sensitivity across the wake
% d(Integral)/dh_up = Integral( df/dh_up dy )
dInt_dhup = trapz(y, df_dhup);
sens_hup = (2 / D) * dInt_dhup;

% Uncertainty contribution from h_up
u_Cd_hup = abs(sens_hup) * u_h;

% C. Sensitivity to Wake Heads (h_w_i)
% Each h_w_i is an independent measurement (Random/Uncorrelated error)
% dr/dh_w = 0.5 * r / h_w
% df/dh_w = (1 - 2r) * (0.5 * r / h_w)
df_dhw = (1 - 2*r) .* (0.5 * r ./ h_w);

% Handling the integration weights for Trapezoidal rule:
% Integral ~ sum( w_i * f_i ) where w_i involves delta_y
% Sensitivity for point i: d(Cd)/dh_wi = (2/D) * weight_i * (df/dh_w)_i
N = length(y);
sens_hw = zeros(1, N);
dy = diff(y);

for i = 1:N
    % Determine trapezoidal weight for point i
    if i == 1
        weight = dy(1) / 2;
    elseif i == N
        weight = dy(end) / 2;
    else
        weight = (dy(i-1) + dy(i)) / 2;
    end
    
    sens_hw(i) = (2 / D) * weight * df_dhw(i);
end

% Uncertainty contribution from all h_w points (Root Sum Square)
u_Cd_hw = sqrt(sum((sens_hw * u_h).^2));


% --- 5. Total Combined Uncertainty ---
% u_total^2 = u_D^2 + u_hup^2 + sum(u_hw_i^2)
u_Cd_total = sqrt(u_Cd_D^2 + u_Cd_hup^2 + u_Cd_hw^2);
u_Cd_expanded = 2 * u_Cd_total; % 95% Confidence (k=2)

% --- 6. Display Results ---
fprintf('\n--- Uncertainty Analysis (Analytical Method) ---\n');
fprintf('Uncertainty Contributions:\n');
fprintf('  Diameter (D):       %.4f\n', u_Cd_D);
fprintf('  Upstream Head (h0): %.4f (Correlated)\n', u_Cd_hup);
fprintf('  Wake Heads (h_i):   %.4f (Uncorrelated Sum)\n', u_Cd_hw);
fprintf('-------------------------------------------\n');
fprintf('Combined Standard Uncertainty (u_Cd): %.3f\n', u_Cd_total);
fprintf('Expanded Uncertainty (k=2, 95%%):     %.3f\n', u_Cd_expanded);
fprintf('\nFinal Result:\n');
fprintf('Cd = %.2f +/- %.2f (95%%)\n', Cd, u_Cd_expanded);
