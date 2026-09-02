%Display welcome message
disp(['Welcome to game 21. Your goal is to draw random numbers' ...
    ' between 0 and 10 and add them up to get as close to 21' ...
    ' as possible. Good luck!'])

%initialize variable to keep track of sum
sum = 0;

%initialize flag to determine if player is out
out = false;

while ~out
    %Draw a random integer between 0 and 10
    draw = floor(11*rand());

    %update sum
    sum = sum + draw;

    %Display drawn number
    fprintf('You drew %.d \n', draw)

    %Display sum
    fprintf('Your total sum is now %.d \n', sum)

    %Check is player is out
    if sum>21
        disp(['As you can see you have exceedeed 21 and is' ...
            ' now out of the game'])
        out = true;
        break;
    end

    %Give player choice between drawing and stopping
    choice = input('Do you want to draw another card? (y/n)', 's');

    %Stop the game if the player wants so
    if choice == 'n'
        disp('You decided to stop.');
        break;
    end
end

%Write the result to the player
fprintf('Your final sum is %.d \n', sum)
if sum > 21
    disp('You unfortunately lost the game.')
end