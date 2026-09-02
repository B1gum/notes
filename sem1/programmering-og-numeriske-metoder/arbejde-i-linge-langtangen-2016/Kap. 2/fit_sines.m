%sum of sines function
function S_N = sinesum(t, b)
    %initialize the output array S_N to zero, with the same size as t
    S_N = zeros(size(t));
    
    %loop over each element of t to compute S_N(t) for each time value
    for j = 1:length(t)
        %compute the sum for the j-th time point
        S_N(j) = sum(b .* sin((1:length(b)) * t(j)));
    end
end

%test function for sinesum
function test_sinesum()
    %define test case values
    t = [-pi/2, pi/4];  %time points
    b = [4, -3];         %coefficients b_1 and b_2
    N = length(b);      %number of sine terms (N)
    
    %call the sinesum function to compute S_N(t)
    S_N_computed = sinesum(t, b);

    fprintf('Computed values are %.4f and %.4f\n', S_N_computed(1), S_N_computed(2));
end

%plotting function
function plot_compare(f, N, M)
    %create time-array containing M evenly distributed points in [-pi, pi]
    t = linspace(-pi, pi, M);

    %Values of b_n
    b = [4,-3];

    %original function
    f_t = f(t);

    %Sinesum approximation
    S_N_t = sinesum(t, b);

    %plot original function and sine sum
    plot(t, f_t, '-');
    hold on;
    plot(t, S_N_t, '-');
    title('Comparison of f(t) and Sine Sum Approximation');
    xlabel('t');
    ylabel('Function values');
    legend("Original function", "Sinesum approximation");
    grid on;
    hold off;
end

function E = error(b, f, M)
    %create time-array containing M evenly distributed points in [-pi, pi]
    t = linspace(-pi, pi, M);

    %original function
    f_t = f(t);

    %Sinesum approximation
    S_N_t = sinesum(t, b);

    %Beregn kvadreret fejl
    squared_error = (f_t-S_N_t).^2;

    %Beregn RMSE
    E = sqrt(sum(squared_error)/M);
end

function plot_line_compute_error(f, n)
    %set M
    M = 500;

    %create time-array containing M evenly distributed points in [-pi, pi]
    t = linspace(-pi, pi, M);

    %initialize array for b-values
    b = zeros(1,n);

    while true
        %Get b values
        fprintf("Indtast %.d værdier \n", n)
        for i = 1:n
            b(i) = input(sprintf('Enter b_%d: ', i));
        end
        
        %Allows user to exit by setting b = 0
        if all(b == 10)
            break;
        end

        %Define function to plot
        f_t = f(t);

        %Sinesum approximation
        S_N_t = sinesum(t, b);

        %Call error-function
        E = error(b, f, M);

        %Display the computed error
        fprintf("the calculated error is e = %.4f \n", E);

        %Make figure
        figure;
        hold on;
        plot(t, f_t, '-');
        plot(t, S_N_t, '-');
        xlabel('t(tid)');
        ylabel('y');
        legend('Given function', 'Sinefit');
        title(sprintf('Fit of sines'));
        grid on;
        hold off;
    end
end

function sine_fit(f, n)
    %set M
    M = 500;

    %create time-array containing M evenly distributed points in [-pi, pi]
    t = linspace(-pi, pi, M);

    %Initialize best error to large value
    best_error = 10000;

    %Initialize array for best value of b
    best_b = [0,0,0,0];

    %define range
    range = -1:0.1:1;

    for b1 = range
        for b2 = range
            for b3 = range
                for b4 = range
                        %Set current b
                        b = [b1, b2, b3, b4];
                        %Call error-function
                        E = error(b, f, M);

                        %save best
                        if E < best_error
                            best_error = E;
                            best_b = b;
                        end
                end
            end
        end
    end
    
    %Display the best error and coefficients
    fprintf('Smallest error: %.4f\n', best_error);
    fprintf(['Best coefficients: b_1 = %.2f, b_2 = %.2f, b_3 = %.2f,' ...
        ' b_4 = %.2f\n'], best_b(1), best_b(2), best_b(3), best_b(4));


    %Compute function
    f_t = f(t);

    %Compute the sine sum with best coefficients
    S_N_t = sinesum(t, best_b);

    %Plot results
    figure;
    hold on;
    plot(t, f_t, 'b-');
    plot(t, S_N_t, 'r-');
    xlabel('t');
    ylabel('y');
    legend('Original function', 'Best Sinefit');
    title('Best Sinefit Approximation with 3 Terms');
    grid on;
    hold off;
end


% Define the original function f(t) as a function handle
f = @(t) (1/pi) * t;

sine_fit(f, 4);