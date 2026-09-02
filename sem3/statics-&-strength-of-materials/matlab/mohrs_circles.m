clc; clear; close all;

%% ===== STRESS STATE (MPa) =====
sigma_x  = 0;
sigma_y  = 30;
sigma_z  = 120;

tau_xy = 0;
tau_xz = 0;
tau_yz = 70;

Sigma = [ sigma_x   tau_xy   tau_xz;
          tau_xy    sigma_y  tau_yz;
          tau_xz    tau_yz   sigma_z ];

%% ===== PRINCIPAL STRESSES =====
principalStresses = sort(eig(Sigma),'descend');
sigma1 = principalStresses(1);
sigma2 = principalStresses(2);
sigma3 = principalStresses(3);

%% ===== MOHR CIRCLE PARAMETERS =====
theta = linspace(0,2*pi,500);
C13 = (sigma1 + sigma3)/2;   R13 = (sigma1 - sigma3)/2;
C12 = (sigma1 + sigma2)/2;   R12 = (sigma1 - sigma2)/2;
C23 = (sigma2 + sigma3)/2;   R23 = (sigma2 - sigma3)/2;
Rmax = max([R13 R12 R23]);

%% ===== MAIN AXES =====
figure;
ax1 = axes;
hold(ax1,'on'); grid(ax1,'on'); axis(ax1,'equal');

% Filled circles
h1_all = fill(C13 + R13*cos(theta), R13*sin(theta), [0.85 0.2 0.2], ...
    'EdgeColor','k','LineWidth',2);
h2_all = fill(C12 + R12*cos(theta), R12*sin(theta), [0.2 0.85 0.2], ...
    'EdgeColor','k','LineWidth',2);
h3_all = fill(C23 + R23*cos(theta), R23*sin(theta), [0.2 0.2 0.85], ...
    'EdgeColor','k','LineWidth',2);

% Use first patch handle for legend
h1 = h1_all(1); 
h2 = h2_all(1); 
h3 = h3_all(1);

% Max shear points (colored dots)
d1_all = plot(C13,[ R13 -R13],'ko','MarkerFaceColor', [0.85 0.2 0.2]);
d2_all = plot(C12,[ R12 -R12],'ko','MarkerFaceColor', [0.2 0.85 0.2]);
d3_all = plot(C23,[ R23 -R23],'ko','MarkerFaceColor', [0.2 0.2 0.85]);

% Use only first dot handle for legend
d1 = d1_all(1); 
d2 = d2_all(1); 
d3 = d3_all(1);

%% ===== AXES LABELS =====
xlabel('\sigma (Normal Stress)  [MPa]')
ylabel('\tau (Shear Stress)  [MPa]')
title('Mohr''s Circles for Given Stress State')

%% ===== LEGEND (CIRCLES + TAU DOTS) =====
legend([h1 h2 h3 d1 d2 d3], ...
    {'\sigma_1-\sigma_2 Circle', '\sigma_{int}-\sigma_1 Circle', '\sigma_2-\sigma_{int} Circle', ...
     sprintf('\\tau_{max} = %.1f MPa', R13), sprintf('\\tau = %.1f MPa', R12), sprintf('\\tau = %.1f MPa', R23)}, ...
    'Location','southeast');

%% ===== AXIS LIMITS =====
ylim(ax1,1.15*[-Rmax Rmax]);

%% ===== MIRRORED RIGHT AXIS (NO TICKS / LABELS) =====
ax2 = axes('Position',ax1.Position, 'Color','none', ...
           'YAxisLocation','right', 'XTick',[], 'YTick',[], 'Box','off');
linkaxes([ax1 ax2],'y');
