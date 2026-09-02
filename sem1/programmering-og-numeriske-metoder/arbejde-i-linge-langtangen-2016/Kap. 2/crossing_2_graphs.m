N = 400;
e = 0.01;

x_min = -4;
x_max = 4;

x = (abs(x_min) + abs(x_max))/N + x_min

while x <= 4
    if abs(x-x^2) < e
    fprintf("De krydser ved %.4f.\n", x);
    end
    x = x + (x_max-x_min)/N;
end