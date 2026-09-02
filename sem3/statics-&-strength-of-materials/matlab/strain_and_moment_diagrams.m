%% Shear and Moment Diagram - Test Case
clear; clc; close all;

%% Beam domain
x = linspace(0, 4, 1000); % beam length

%% Define piecewise shear V(x)
V = @(x)    (x>0 & x<1.5).* (-1277) + ...
            (x>=1.5 & x<4).* (-1277+2043) + ...
            (x>=4 & x<=4).* (-1277+2043-765.96);

Vx = V(x);

%% Define bending moment M(x) (integral of V(x))
dx = x(2) - x(1);
Mx = cumtrapz(x, Vx);

%% Create a taller figure
figure('Color','w','Position',[100 100 900 600]); % increased height from 400 to 600

%% Shear diagram
subplot(2,1,1)
plot(x, Vx, 'b','LineWidth',2); hold on
area(x, Vx, 'FaceColor', [0 0 1], 'FaceAlpha', 0.2, 'EdgeColor','none');

% Center x-axis vertically
ylimMax = max(abs(Vx))*1.2;
ylim([-ylimMax ylimMax]);
yline(0,'k','LineWidth',1.5);
xlim([0,max(x)]);

xlabel('x [m]'); ylabel('Shear [N]')
title('Shear Diagram')
grid on

%% Moment diagram
subplot(2,1,2)
plot(x, Mx, 'r','LineWidth',2); hold on
area(x, Mx, 'FaceColor', [1 0 0], 'FaceAlpha', 0.2, 'EdgeColor','none');

ylimMax = max(abs(Mx))*1.2;
ylim([-ylimMax ylimMax]);
yline(0,'k','LineWidth',1.5);
xlim([0,max(x)]);

xlabel('x [m]'); ylabel('Moment [N\cdot m]')
title('Moment Diagram')
grid on