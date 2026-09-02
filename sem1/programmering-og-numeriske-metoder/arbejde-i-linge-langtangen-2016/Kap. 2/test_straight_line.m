%Define number of points
n = 100;

%Initialize arrays
r = zeros(1,100);

%Define the function
f = @(x) 4 * x + 1;

%Define the slope
a = 4;

%Define fixed point
c = 2;

%Define interval
x_min = 0;
x_max = 10;

%Make random numbers
r = rand(1,n)*(x_max-x_min) + x_min;

%Run rest
for i = 1:n
    lhs = (f(r(i))-f(c))/(r(i)-c);
    if (f(r(i))-f(c))/(r(i)-c) == a
        fprintf("Testpunkt: %.d. Tilfældigt tal: %.4f. Test bestået %.4f = %.d \n", i,r(i),lhs,c)
    else 
        fprintf("Testpunkt: %.d. Tilfældigt tal: %.4f. Test fejlet %.4f ~= %.d \n", i,r(i),lhs,c)
    end
end