function [x, i] = Newton(f, dfdx, x0, pars)
    % Solves f(x)=0 using Newton's method
    % f is a function handle to f(x).
    % dfdx is a function handle to dfdx(x).
    % x0 is the starting point.
    % pars is optional and may contain fields eps, imax, 
    % all_x_values and/or print.
    % The iteration stops when |f(x)| <= eps or imax iterations used.
    % Solution x and i, number of calls to f(x), are returned.
    % i = -1 if |f(x)| > eps
    % i = -2 if |dfdx| < 1e-15
    
    if nargin <= 3; pars = struct(); end
    pars = handle_default_parameters(pars);
    
    x = x0;
    if pars.all_x_values; x_all = [x]; end
    i = 1;
    fx = f(x);
    
    while abs(fx) > pars.eps && i <= pars.imax
        df = dfdx(x);
        if abs(df) <= 1e-15
            fprintf('Error! dfdx=%g very small at x = %g\n', df, x);
            i = -2;
            return
        else
            x = x - fx / df;
        end
        fx = f(x);
        i = i + 1;
        if pars.print
            fprintf('i=%6d x=%16.10g f(x)=%16.10g\n', i, x, fx);
        end
        if pars.all_x_values; x_all(end + 1) = x; end
    end
    
    if abs(fx) > pars.eps; i = -1; end
    if pars.all_x_values; x = x_all; end
end

function new_pars = handle_default_parameters(pars)
    % Returns a new pars struct with all fields and fields not
    % in pars get a default value.
    new_pars = struct('eps', 1e-6, 'imax', 25, ...
                      'all_x_values', false, 'print', false);
    if isfield(pars, 'eps'); new_pars.eps = pars.eps; end
    if isfield(pars, 'imax'); new_pars.imax = pars.imax; end
    if isfield(pars, 'all_x_values')
        new_pars.all_x_values = pars.all_x_values; 
    end
    if isfield(pars, 'print'); new_pars.print = pars.print; end
end