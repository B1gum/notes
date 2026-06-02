%% Problem 1

clc; clear variables; close all;

%%%%% Geometry / mesh / setup %%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
Lx = 30; % Eq. 3
Ly = 30; % Eq. 3
X_mesh = 90;
Y_mesh = 90;

% Using Eq. 1
N = X_mesh + 1; %Eq. 5
M = Y_mesh + 1; %Eq. 5

% Create grid with N,M points between 0 and Lx,Ly 
x = linspace(0,Lx,N);
y = linspace(0,Ly,M);

h = x(2)-x(1); % Step length

numGridPoints = N*M; % Amount of grid points/unknowns

f = @(x,y) exp(-((x-15).^2)/4) + exp(-((y-15).^2)/4); % Define the function f(x,y) from solution, Eq. 2
k = @(i,j) i + (j-1)*N; % Store the grid as a long vector, u_(1,1) -> u_1, u_(2,1) -> u_2, u_(N,1) -> u_N, u(1,2) -> u_(N+1), Eq. 7

% Dirichlet boundary values
u_left  = 0;
u_right = 20;

% Von Neumann boundary values
g_bottom = 0;
g_top    = 1;

% Preallocate sparse matrix
maxnnz = 9*numGridPoints; % The largest stencil is the interior stencil, which uses 9 grid points, meaning every row of A can have at most 9 entries
b = zeros(numGridPoints,1); % Preallocate matrix b in Eq. 6

% We store the matrix, A in Eq. 6 as a sparse matrix.
% This is created as A(I(q), J(q)) = V(q) 
I = zeros(maxnnz,1); % Preallocate row indices
J = zeros(maxnnz,1); % Preallocate column indices
V = zeros(maxnnz,1); % Preallocate nonzero-coefficients matrix
p = 0; % Amount of sparse matrix entries thus far

%%%%% Matrix assembly loop %%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% This loop is building the lineary system Au = b, where every grid point
% (i,j) becomes one row in the matrix. `row` represents the current
% equation/grid-point, `cols` are the unknowns in said equation, `vals` are
% the coefficients multiplying those equations and `b(row)` is the 
for j = 1:M
    for i = 1:N
        % Create one equation at each grid point
        row = k(i,j); % Determine which row of A point (i,j) corresponds to

        if i == 1 % Left boundary
            % Left stencil
            cols = row;
            vals = 1;
             % Force left boundary to u_left, Eq. 12
            b(row) = u_left;

        elseif i == N % Right boundary
            % Right stencil
            cols = row;
            vals = 1;
            % Force right boundary to u_right, Eq. 13
            b(row) = u_right;

        elseif j == 1 % Bottom boundary
            % Bottom stencil
            cols = [k(i,j), k(i-1,j), k(i+1,j), k(i,j+1)];
            vals = [4, -1, -1, -2];
            % Von Neumann condition at bottom, Eq. 15
            b(row) = -h^2*f(x(i),y(j)) - 2*h*g_bottom;

        elseif j == M % Top boundary
            % Top stencil
            cols = [k(i,j), k(i-1,j), k(i+1,j), k(i,j-1)];
            vals = [4, -1, -1, -2];
            % Von Neumann condition at top, Eq. 16
            b(row) = -h^2*f(x(i),y(j)) + 2*h*g_top;

        else % Interior point
            % General stencil
            cols = [k(i,j), k(i-1,j), k(i+1,j), k(i,j-1), k(i,j+1), ...
                    k(i+1,j+1), k(i+1,j-1), k(i-1,j+1), k(i-1,j-1)];
            vals = [4, -1, -1, -1, -1, -1/4, 1/4, 1/4, -1/4];
            b(row) = -h^2*f(x(i),y(j)); % Eq. 11
        end

        nn = numel(cols); % Amount of coefficients in current equation

        % Insert coefficients into sparse storage arrays
        I(p+1:p+nn) = row;
        J(p+1:p+nn) = cols;
        V(p+1:p+nn) = vals;

        % Update amount of spare-matrix entries
        p = p + nn;
    end
end

% Create a sparse matrix A of the form A(I(q), J(q)) = V(q) with dimensions
% numGridPoints*numGridPoints
A = sparse(I(1:p),J(1:p),V(1:p),numGridPoints,numGridPoints);

% Solve direct system, Eq. 6
u_vec = A\b;

% Convert long vector u, Eq. 7, into a 2D matrix of size N*M
u = reshape(u_vec,N,M);

% Plot
[X,Y] = meshgrid(x,y);
figure;
surface(X,Y,u');
view(3);
shading interp;
colorbar;
title("Steady-state solution u(x,y)");
xlabel("x");
ylabel("y");
zlabel("u");

%% Problem 2
clc; clear variables;

% Parameters
alpha = 1;
nu    = 0.1;
c     = 0.05;

L  = 20;
T  = 20;
dt = 0.01;

numIntervals = 100;
N = numIntervals + 1; % Eq. 19
x = linspace(0, L, N)'; % Eq. 23
dx = x(2) - x(1); % Eq. 20
Nt = round(T/dt); % Eq. 22

% Boundary condition data
leftBC = @(t) sin(t).^2; % Eq. 27
qRight = -0.2;       % Eq. 28

% Initial condition
u = exp(-(x - 5).^2); % Eq. 26

% Enforce left boundary at t = 0
u(1) = leftBC(0); 

% Enforce right Neumann condition at t = 0
u(end) = u(end-1) + dx*qRight;

% Crank-Nicolson coefficients
r = nu*dt/(2*dx^2); % Eq. 33
s = alpha*dt/(4*dx);  % Eq. 34
k = c*dt/2; % Eq. 35

A = spalloc(N, N, 3*N);
B = spalloc(N, N, 3*N);

% Interior points using Eq. 37
for i = 2:N-1
    % Left-hand side: u^{n+1}
    A(i,i-1) = -r - s;
    A(i,i)   =  1 + 2*r + k;
    A(i,i+1) = -r + s;

    % Right-hand side: u^n
    B(i,i-1) =  r + s;
    B(i,i)   =  1 - 2*r - k;
    B(i,i+1) =  r - s;
end

% Left Dirichlet boundary: u(0,t) = sin^2(t)
A(1,1) = 1;
B(1,:) = 0;

% Right Neumann boundary: du/dx = -0.2

A(N,N)   = 1;
A(N,N-1) = -1;
B(N,:)   = 0;

% Times to store for final plot
snapshotTimes = [2 5 7 10 12 15 18 20];
snapshotSteps = round(snapshotTimes/dt);

snapshots = zeros(N, length(snapshotTimes));
snapshotCounter = 1;

% Animation setup
figure;
h = plot(x, u);
grid on;
xlabel("x");
ylabel("u(x,t)");
title("Drug concentration");
ylim([-0.2 1.2]);

% Time stepping
for n = 0:Nt-1
    tNew = (n+1)*dt;

    rhs = B*u;

    % Apply boundary values at the new time level
    rhs(1) = leftBC(tNew);
    rhs(N) = dx*qRight;

    % Solve the linear system
    u = A\rhs;

    % Store snapshots
    if snapshotCounter <= length(snapshotSteps) && n+1 == snapshotSteps(snapshotCounter)
        snapshots(:,snapshotCounter) = u;
        snapshotCounter = snapshotCounter + 1;
    end

    % Animate every few steps
    if mod(n,5) == 0 || n == Nt-1
        set(h, "YData", u);
        title(sprintf("Drug concentration, t = %.2f s", tNew));
        drawnow;
    end
end

% Plot requested time profiles
figure;
plot(x, snapshots);
grid on;
xlabel("x");
ylabel("u(x,t)");
title("Drug concentration at selected times");

legendLabels = arrayfun(@(tt) sprintf("t = %g s", tt), ...
    snapshotTimes, "UniformOutput", false);

legend(legendLabels, "Location", "best");