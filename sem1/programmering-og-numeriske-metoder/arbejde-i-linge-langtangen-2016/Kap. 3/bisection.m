function [x_M, f_counter] = bisection(f, x_L, x_R, pars)

    if nargin < 4
        pars = struct();
    end

    pars = handle_default_parameters(pars);

    % Initial function evaluations
    f_L = f(x_L);
    f_R = f(x_R);

    % Check if signs are opposite (root exists in interval)
    if f_L * f_R > 0
        fprintf('Error! Function does not have opposite signs at the interval endpoints.\n');
    end

    % Iterative bisection
    x_M= (x_L+ x_R)/2;
    f_M= f(x_M);
    f_counter= 3;
    
    if pars.all_x_values
        x_all = [x_M];
    end

    % Print initial information if required
    if pars.print
        fprintf('Iteration %d: [xL, xM, xR] = [%f, %f, %f], f(xM) = %e\n', ...
            0, x_L, x_M, x_R, f_M);
    end

    i = 1;

    while abs(f_M) > pars.eps && f_counter < pars.imax
        % Update interval based on the sign of f(x)
        if f_L * f_M > 0
            x_L = x_M;
            f_L = f_M;
        else
            x_R = x_M;
        end

        x_M= (x_L+ x_R)/2;
        f_M= f(x_M);
        f_counter= f_counter+ 1;

        if pars.all_x_values
            x_all(end+1)=x_M;
        end

        % Print iteration information if required
        if pars.print
            fprintf('Iteration %d: [xL, xM, xR] = [%f, %f, %f], f(xM) = %e\n', i, x_L, x_M, x_R, f_M);
        end

        i = i + 1;
    end

    if abs(f_M)>pars.eps
        f_counter=-1;
    end

    if pars.all_x_values
        x_M=x_all;
    end
end

function new_pars = handle_default_parameters(pars)
    % Set default values for parameters
    new_pars = struct('eps', 1e-6, 'imax', 100, ...
                      'all_x_values', false, 'print', false);
    if isfield(pars, 'eps'); new_pars.eps = pars.eps; end
    if isfield(pars, 'imax'); new_pars.imax = pars.imax; end
    if isfield(pars, 'all_x_values'); new_pars.all_x_values = pars.all_x_values; end
    if isfield(pars, 'print'); new_pars.print = pars.print; end
end
