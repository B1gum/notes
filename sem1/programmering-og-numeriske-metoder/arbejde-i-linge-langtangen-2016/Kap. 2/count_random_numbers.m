%Get a value of N
N = input("Hvor mange tilfældige tal skal trækkes?");

%Make an array to store all the random numbers in
random_numbers = zeros(1, N);

% Initialize a counter to keep track of the amount of 6's drawn
count_sixes = 0;

%Draw N random numbers
for i = 1:N
    random_numbers(i) = 1+floor(6*rand()); %Draw a number

    %Update counter if the drawn number is 6
    if random_numbers(i) == 6
        count_sixes = count_sixes + 1;
    end
end

%Display the generated random numbers
disp('De tilfældige tal er:')
disp(random_numbers)

%Calculate the fraction count_sixes/n
fraction_sixes = count_sixes / N;

% Display the fraction of numbers that are 6
fprintf('Andelen af de tilfældige tal som er 6 er %.2f\n',...
    fraction_sixes)