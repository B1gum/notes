clc; clear variables; close all;

%% Read data
data = readtable("data/Statistik og experimentelle metoder,S26-o,bilag2.csv", ...
                 "Delimiter", ";", ...
                 "DecimalSeparator", ",");

x = data.x;
y = data.y;

%% Polynomial regression of order p = 2
p = 2;

% polyfit returns coefficients in descending powers:
% coeffs = [beta2 beta1 beta0]
coeffs = polyfit(x, y, p);

% Evaluate fitted polynomial at the original x-values
y_hat = polyval(coeffs, x);

%% Extract coefficients
beta2 = coeffs(1);
beta1 = coeffs(2);
beta0 = coeffs(3);

fprintf("Estimated coefficients:\n");
fprintf("beta0 = %.6f\n", beta0);
fprintf("beta1 = %.6f\n", beta1);
fprintf("beta2 = %.6f\n", beta2);

fprintf("\nFitted polynomial:\n");
fprintf("y_hat = %.6f %+ .6f*x %+ .6f*x^2\n", ...
        beta0, beta1, beta2);

%% Calculate SSE, SST, R^2 and adjusted R^2
SSE = sum((y - y_hat).^2);
SST = sum((y - mean(y)).^2);

R2 = 1 - SSE/SST;

n = length(y);

d_res = n - p - 1;
d_tot = n - 1;

R2_adj = 1 - (SSE/d_res)/(SST/d_tot);

fprintf("\nGoodness of fit:\n");
fprintf("SSE = %.6f\n", SSE);
fprintf("R^2 = %.6f\n", R2);
fprintf("Adjusted R^2 = %.6f\n", R2_adj);

%% Plot data and fitted polynomial
x_plot = linspace(min(x), max(x), 400);
y_plot = polyval(coeffs, x_plot);

figure;
scatter(x, y, "filled");
hold on;
plot(x_plot, y_plot, "LineWidth", 2);
grid on;

xlabel("x");
ylabel("y");
title("Polynomial regression of order p = 2");
legend("Observed data", "Fitted second-order polynomial", ...
       "Location", "northwest");