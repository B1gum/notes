x = [0, 5, 5];
y = [0, 10, 0];

function A = parea(x, y)
    for k = 1:length(x)
        A = 1/2 * ((idx(k)*idy(k+1)) - idy(k)* idx(k+1))
    end
end

parea(x, y)

% lorteopgave