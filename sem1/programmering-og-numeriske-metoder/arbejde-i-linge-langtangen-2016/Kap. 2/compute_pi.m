N = input("Hvor mange led skal indgå i hver af de to summer");


function Leibniz = L(N)
    k = 0:N-1; %Indekser fra 0 til N-1 for at få N indexer hvoraf det første er 0
    Leibniz = 8 * sum(1 ./ ((4*k+1) .* (4*k+3)));
end 

function Euler = E(N)
    k = 1:N; 
    Euler = sqrt(6*sum(1 ./ k.^2));
end

%Initialize arrays to store values of the error for each N
error_L = zeros(1, N);
error_E = zeros(1, N);

for n = 1:N
    % Calculate approximations for current N
    L_approx = L(n);
    E_approx = E(n);
    
    % Calculate absolute errors
    error_L(n) = abs(L_approx - pi);
    error_E(n) = abs(E_approx - pi);
end

% Plot the errors for both methods
figure;
hold on;
plot(1:N, error_L, 'r', 'DisplayName', 'Leibniz Error');
plot(1:N, error_E, 'b', 'DisplayName', 'Euler Error');
xlabel('Number of Terms (N)');
ylabel('Error');
legend;
title('Error in Approximating \pi with Leibniz and Euler Methods');
hold off;

fprintf("Fejlen ved Leibniz metode med N = %.d er %.4f \n", N, L(N)-pi)
fprintf("Fejlen ved Eulers metode med N = %.d er %.4f", N, E(N)-pi)