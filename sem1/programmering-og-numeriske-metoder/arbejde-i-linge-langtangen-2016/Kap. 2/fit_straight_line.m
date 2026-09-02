%Define array for measurements
y_i = [0.5, 2.0, 1.0, 1.5, 7.5];
i = [0, 1, 2, 3, 4];

function error = compute_error(a, b, i, y_i)
    %Define line
    y_line = a * i + b;

    %Compute error
    error = sum((y_line-y_i).^2);
end

function plot_line_compute_error(i,y_i)
    while true
        %Get a and b values
        a = input("Indtast en a-værdi til brug i beregningen: \n");
        b = input("Indtast en b-værdi til brug i beregningen: \n");
        
        %Allows user to exit by setting a = 0 and b = 0
        if a == 0 && b == 0
            break;
        end

        %Define line to plot
        y_line = a * i + b;

        %Call error-function
        error = compute_error(a, b, i, y_i);

        %Display the computed error
        fprintf("For the inputted a = %.2f and b = %.2f, the" + ...
            " calculated error is e = %.4f \n", a, b, error);

        %Make figure
        figure;
        hold on;
        plot(i, y_i, 'o');
        plot(i, y_line, '-');
        xlabel('i(tid)');
        ylabel('y(measurements)');
        legend('Measured data', 'Fitted line');
        title(sprintf('Fit of straight line: f(x) = %.2fx + %.2f', a, b));
        grid on;
        hold off;
    end
end

plot_line_compute_error(i,y_i);