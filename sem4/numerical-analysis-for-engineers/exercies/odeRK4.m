function y = odeRK4(f, y0, t)
% Solves an ordinary differential equation using the
% 4th order Runge-Kutta method.
%
% Inputs: f    Function handle for evaluating the ODE
%         y0   Initial condition/value
%         t    Time vector [t_0 t_1 t_2 ... t_n]
% Output: y    Resulting values at each time step in t

    n = length(t);

    y = zeros(n,1);
    y(1) = y0;

    for i = 1:n-1
        h = t(i+1) - t(i);

        % k's
        k1 = f(t(i), y(i));
        k2 = f(t(i) + h/2, y(i) + h/2 * k1);
        k3 = f(t(i) + h/2, y(i) + h/2 * k2);
        k4 = f(t(i) + h, y(i) + h * k3);

        % 4th order RK
        y(i + 1) = y(i) + h * (1/6 * k1 + 1/3 * (k2 + k3) + 1/6 * k4);
    end

end