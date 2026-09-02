%Define ranks and suits
ranks = {'A', '2', '3', '4', '5', '6', '7', '8', '9', '10', 'J', 'Q', 'K'};
suits = {'C', 'D', 'H', 'S'};

%Initialize a cell array to store deck of cards
deck = cell(1, 52);

%Define an index variable used to keep track of how far we've come
index_c = 1;

%Generate the deck using a nested for loop
for s = 1:length(suits)
    for r = 1:length(ranks)
        deck{index_c} = [suits{s} ranks{r}];
        index_c = index_c+1;
    end
end

%disp(deck)



%Define the lettes and numbers that can be used on a license plate
letters = {'A','B','C','D','E','F','G','H','I','J','K','L','M','N',...
    'O','P','Q','R','S','T','U','V','W','X','Y','Z'};
numbers = {'0','1','2','3','4','5','6','7','8','9'};

%Initialize a cell array to store the license plate combinations
plates = cell(1,length(letters)^2*length(numbers)^3);

%Define an index variable used to keep track of how far we've come
index_p = 1;

%Generate the plates using a nested for loop
for l_1 = 1:length(letters)
    for l_2 = 1:length(letters)
       for n_1 = 1:length(numbers)
           for n_2 = 1:length(numbers)
               for n_3 = 1:length(numbers)
                    plates{index_p} = [letters{l_1} letters{l_2} ...
                        numbers{n_1} numbers{n_2} numbers{n_3}];
                    index_p = index_p+1;
               end
           end
       end
    end
end

%disp(plates)


%Define the possible dice rolls
eyes = {1, 2, 3, 4, 5, 6};

%Initialize a cell array to store the dice combinations
dice = cell(1, length(eyes)^2);

%Define an index variable used to keep track of how far we've come
index_d = 1;

%Define an array to store all the cominations that sum up to 7
pairs_7 = {};

%Generate the deck using a nested for loop
for e_1 = 1:length(eyes)
    for e_2 = 1:length(eyes)
        dice{index_d} = [eyes{e_1} eyes{e_2}];

        % Check if the sum of the dice equals 7
        if eyes{e_1} + eyes{e_2} == 7
            pairs_7{end+1} = [eyes{e_1}, eyes{e_2}]; % Store pairs that sum to 7
        end

        index_d = index_d+1;
    end
end

disp('Pairs that sum to 7:');
disp(pairs_7)