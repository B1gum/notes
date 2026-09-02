function [x, f_val] = bisection_ewton(f, df, x_L, x_R, s, pars)
    %default parameters
    if nargin < 5 || isempty(s)
        s = 0.1; %default fraction for bisection stopping condition
    end
    if nargin < 6
        pars = struct(); %set default
    end
    
    %handle parameters
    pars = handle_default_parameters(pars);
    
    %initial interval and function evaluations
    f_L = f(x_L);
    f_R = f(x_R);

    if f_L * f_R > 0
        error('Function does not change sign in the interval. Bisection cannot proceed.');
    end

    initial_interval_length = abs(x_R - x_L);

    %bisection
    while abs(x_R - x_L) > s * initial_interval_length
        x_M = (x_L + x_R) / 2;
        f_M = f(x_M);
        
        %optional printing
        if pars.print
            fprintf('Bisection: [x_L,x_M,x_R]=[%12.6g,%12.6g,%12.6g] f(x_M)=%12.6g\n', x_L, x_M, x_R, f_M);
        end

        if f_M == 0
            %root found during bisection
            x = x_M;
            f_val = f_M;
            iterations = -1;
            return;

        elseif f_L * f_M < 0
            x_R = x_M;
            f_R = f_M;

        else
            x_L = x_M;
            f_L = f_M;
        end
    end
    
    %newton
    x = (x_L + x_R) / 2; %midpoint of new interval
    for i = 1:pars.imax
        f_val = f(x);
        df_val = df(x);
        
        if abs(f_val) < pars.eps
            %root found
            iterations = i;
            return;

        elseif abs(df_val) < pars.eps
            %derivative too small, fallback to bisection
            warning('Derivative near zero. Switching back to bisection.');
            break;
        end
        
        %newton iteration
        x_new = x - f_val / df_val;
        
        %check if Newton stays in interval
        if x_new < x_L || x_new > x_R
            warning('Newton out of bounds. Switching back to bisection.');
            break;
        end
        
        %update for next iteration
        x = x_new;
        
        %optional printing
        if pars.print
            fprintf('Newton: x=%12.6g f(x)=%12.6g df(x)=%12.6g\n', x, f_val, df_val);
        end
    end
    
    %final fallback to bisection
    warning('Fallback to bisection for convergence.');
    [x, ~] = bisection(f, x_L, x_R, pars);
    f_val = f(x);
end

function new_pars = handle_default_parameters(pars)
    %set default values for parameters
    new_pars = struct('eps', 1e-6, 'imax', 100, ...
                      'all_x_values', false, 'print', false);
    if isfield(pars, 'eps'); new_pars.eps = pars.eps; end
    if isfield(pars, 'imax'); new_pars.imax = pars.imax; end
    if isfield(pars, 'all_x_values'); new_pars.all_x_values = pars.all_x_values; end
    if isfield(pars, 'print'); new_pars.print = pars.print; end
end
