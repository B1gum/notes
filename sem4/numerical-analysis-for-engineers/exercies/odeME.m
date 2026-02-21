function x = odeME(f, x0, t)
% solves an ordinary differential equation using the Modified Euler method.
%
% Inputs: f    Function handle for evaluating the ODE
%         x0   Initial condition
%         t    Time vector [t_0 t_1 t_2 ... t_n]
% Output: x    Resulting function values at each time step in t

    n = length(t);

    x = zeros(n,1);
    x(1) = x0;

    for i = 1:n-1
        h = t(i+1) - t(i);

        % Predictor
        xPred = x(i) + h * f(t(i), x(i));

        % Modified Euler
        x(i+1) = x(i) + (h/2) * ( f(t(i), x(i)) + f(t(i+1), xPred) );
    end
end