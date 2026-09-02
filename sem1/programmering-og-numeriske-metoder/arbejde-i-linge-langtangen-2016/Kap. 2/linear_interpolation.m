%Initialize vectors containing given information
y_values = [4.4, 2.0, 11.0, 21.5, 7.5];
N = length(y_values)-1;
t_values = 0:N;

%Define function that does the linear interpolation
function y_interp = linear_interpolate(y_values, t_values, t)
    N = length(y_values)-1;
    for i = 1:N
        %Find i such that t(i) <= t <= t(i+1)
        if t_values(i) <= t && t < t_values(i+1)
            %Find the equation of the line between (i, y_i) and (i+1, y_(i+1))
            t1 = t_values(i);
            t2 = t_values(i+1);
            y1 = y_values(i);
            y2 = y_values(i+1);
            
            %Slope of the line
            slope = (y2 - y1) / (t2 - t1);
            
            %Equation of the line: y = y1 + slope * (t - t1)
            y_interp = y1 + slope * (t - t1);
            
            return;  %Break out of the loop once the correct interval is found
        end
    end
    y_interp = NaN; %Sets y_interp to NaN if no such i is found
end

%Define function that asks user for a time
function run_interpolation_loop(y_values, t_values)
    N = length(y_values)-1;
    while true
        %Ask user for time
        t = input('Enter a time in the range [0, N] (enter negative value to quit): ');
        if t < 0
            break;
        end

        %Check if inputed time is in range
        if t <= N
            %Call the linear interpolation function
            y_interp = linear_interpolate(y_values, t_values, t);
            fprintf('At time t = %.3f, the interpolated y value is %.3f \n', t, y_interp);
        else
            disp('Invalid time.');
        end
    end
end

% Run the interpolation loop
fprintf('N = %.d \n', N)
run_interpolation_loop(y_values, t_values);