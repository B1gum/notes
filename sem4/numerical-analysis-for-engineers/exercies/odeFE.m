function x = odeFE(f, x0, t)
% solves an ordinary differential equation using the Forward Euler method.
%
% Inputs: f    Function handle for evaluating the ODE
%         x0   Initial condition
%         t    Time vector [t_0 t_1 t_2 ... t_n]
% Output: x    Resulting function values at each time step in t
    n = length(t);      %number of time points

    x = zeros(n,1);
    x(1) = x0;          %initial condition

    for k = 1:n-1
        h = t(k+1) - t(k);
        x(k+1) = x(k) + h*f(t(k),x(k)); % Forward Euler step
    end
end