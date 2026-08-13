clear; clc; close all;

s = tf('s');

% Write the transfer function WITHOUT K:
G = 0.125/(s*(s+1)^2*(s+0.5));

figure;
rlocus(G);
grid on;
title('Root locus of K*G(s)');

figure;
bode(G);
grid on;
title('Bode plot of G(s)');