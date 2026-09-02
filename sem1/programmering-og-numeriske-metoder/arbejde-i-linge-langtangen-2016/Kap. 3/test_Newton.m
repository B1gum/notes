function test_Newton()
    %define test function and  derivative
    f = @(x) x^2 - 4;
    dfdx = @(x) 2 * x;

    %initial guess
    x0 = 3;

    %manual computation of iterations
    manual_x1 = x0; % frst iteration
    manual_x2 = 3 - (f(3) / dfdx(3)); %second iteration

    %call the Newton function
    pars = struct('eps', 1e-6, 'imax', 2, 'all_x_values', true, 'print', true);
    [x_values, iterations] = Newton(f, dfdx, x0, pars);

    %extract the first two iterations
    newton_x1 = x_values(1);
    newton_x2 = x_values(2);

    %compare results
    fprintf('Manual x1: %.6f, Newton x1: %.6f\n', manual_x1, newton_x1);
    fprintf('Manual x2: %.6f, Newton x2: %.6f\n', manual_x2, newton_x2);

    %check correctness
    if abs(manual_x1 - newton_x1) < 1e-6 && abs(manual_x2 - newton_x2) < 1e-6
        fprintf('Test passed: Newton function matches manual computation.\n');
    else
        fprintf('Test failed: Results do not match.\n');
    end
end