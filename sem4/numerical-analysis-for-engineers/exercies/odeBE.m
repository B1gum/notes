function x = odeBE(f, x0, t)
% solves an ordinary differential equation using the Backward Euler method.
%
% Inputs: f    Function handle for evaluating the ODE
%         x0   Initial condition
%         t    Time vector [t_0 t_1 t_2 ... t_n]
% Output: x    Resulting function values at each time step in t
    tol = 1e-10;

    n = length(t);      %number of time points

    x = zeros(n,1);
    x(1) = x0;          %initial condition

    for k = 1:n-1
        h = t(k+1) - t(k);

        % Backward Euler step:
        % x(k+1) = x(k) + h * f(t(k+1), x(k+1))

        z = x(k);       %initial guess for x(k+1)

        for it = 1:50   %Newton iterations
            %g(z) = z - x(k) - h*f(t(k+1), z)  (should be 0)
            g = z - x(k) - h*f(t(k+1), z);

            %g'(z) found with finite difference
            eps = 1e-6*(1 + abs(z));
            g_eps = (z+eps) - x(k) - h*f(t(k+1), z+eps);
            gp = (g_eps - g) / eps;

            z_new = z - g/gp;

            if abs(z_new - z) < tol
                z = z_new;
                break;
            end

            z = z_new;
        end

        x(k+1) = z;
    end
end