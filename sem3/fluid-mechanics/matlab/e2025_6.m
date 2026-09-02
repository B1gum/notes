%% Pressure Coefficient: Experiment vs. Ideal Inviscid Flow
clear; clc; close all;

% --- 1. Experimental Data ---
% Theta [degrees], Manometer h [mm]
theta_exp = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150, 160, 170, 180, ...
             190, 200, 210, 220, 230, 240, 250, 260, 270, 280, 290, 300, 310, 320, 330, 340, 350, 360];

h_surf = [38, 36, 26, 10, -14, -36, -53, -70, -78, -69, -62, -47, -38, -35, -35, -34, -34, -34, -34, ...
          -34, -34, -34, -34, -35, -35, -38, -47, -62, -69, -78, -70, -53, -36, -14, 10, 26, 36];

h_up = 44.0; % Upstream dynamic head [mm]

% Calculate Experimental Cp
Cp_exp = h_surf / h_up;

% --- 2. Ideal Inviscid Theory ---
% Theory: Cp = 1 - 4*sin^2(theta)
theta_ideal = linspace(0, 360, 360); % 0 to 360 degrees
Cp_ideal = 1 - 4 * sind(theta_ideal).^2;

% --- 3. Plotting ---
figure('Color', 'w');
plot(theta_ideal, Cp_ideal, 'k--', 'LineWidth', 1.5, 'DisplayName', 'Ideal Inviscid Solution');
hold on;
plot(theta_exp, Cp_exp, 'ro-', 'LineWidth', 1.5, 'MarkerFaceColor', 'r', 'DisplayName', 'Experimental Data');

% Formatting
xlabel('Angular Position \theta [deg]');
ylabel('Pressure Coefficient C_p');
title('Pressure Distribution on a Cylinder');
legend('Location', 'South');
grid on;
axis([0 360 -3.5 1.5]);

% Mark Separation Region
xline(80, 'b:', 'LineWidth', 1.5, 'DisplayName', 'Separation ~80^\circ');
text(85, -2.5, 'Separation', 'Color', 'b');