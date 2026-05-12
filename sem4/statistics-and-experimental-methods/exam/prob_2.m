clc; clear variables; close all;

%% Read data
% The file uses semicolon as delimiter and comma as decimal separator.
data = readtable("data/Statistik og experimentelle metoder,S26-o,bilag2.csv", "Delimiter", ";", "DecimalSeparator", ",");

x = data.x;
y = data.y;

%% Polynomial regression of order p = 4
% According to Lecture Notes, Section 10.3, the fitted polynomial is
%
% y_hat = beta0 + beta1*x + ... + betap*x^p
%
% For p = 4:
%
% y_hat = beta0 + beta1*x + beta2*x^2 + beta3*x^3 + beta4*x^4

p = 2;

% The lecture notes mention polyfit and polyval as relevant MATLAB functions
% for polynomial regression.
%
% polyfit estimates the least-squares polynomial coefficients.
% MATLAB returns them in descending powers:
%
% coeffs = [beta4 beta3 beta2 beta1 beta0]

coeffs = polyfit(x, y, p);

%% Evaluate fitted values
% polyval evaluates the fitted polynomial at the given x-values.

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
fprintf("y_hat = %.6f %+ .6f*x %+ .6f*x^2 %", ...
        beta0, beta1, beta2);

%% Calculate SSE, SST, R^2 and adjusted R^2
% From the lecture notes:
%
% SSE = sum((y_i - y_hat_i)^2)
% SST = sum((y_i - mean(y))^2)
% R^2 = 1 - SSE/SST

SSE = sum((y - y_hat).^2);
SST = sum((y - mean(y)).^2);

R2 = 1 - SSE/SST;

% Adjusted R^2 from the lecture notes:
%
% R2_adj = 1 - (SSE/d_res)/(SST/d_tot)
%
% where d_res = n - p - 1 and d_tot = n - 1

n = length(y);

d_res = n - p - 1;
d_tot = n - 1;

R2_adj = 1 - (SSE/d_res)/(SST/d_tot);

fprintf("\nGoodness of fit:\n");
fprintf("SSE = %.6f\n", SSE);
fprintf("R^2 = %.6f\n", R2);
fprintf("Adjusted R^2 = %.6f\n", R2_adj);

%% Plot data and fitted polynomial
% The lecture notes say that a first impression about the polynomial degree p
% is gained by consulting the scatter plot.

x_plot = linspace(min(x), max(x), 400);
y_plot = polyval(coeffs, x_plot);

figure;
scatter(x, y, "filled");
hold on;
plot(x_plot, y_plot, "LineWidth", 2);
grid on;

xlabel("x");
ylabel("y");
title("Polynomial regression of order p = 4");
legend("Observed data", "Fitted fourth-order polynomial", ...
       "Location", "northwest");