clc; clear variables; close all;

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

%% Boundary condition data
leftBC = @(t) sin(t).^2; % Eq. 27
qRight = -0.2;       % Eq. 28

%% Initial condition
u = exp(-(x - 5).^2); % Eq. 26

% Enforce left boundary at t = 0
u(1) = leftBC(0);

% Optional: enforce right Neumann condition at t = 0
% This slightly modifies the endpoint because the initial condition
% is not compatible with du/dx = -0.2 at x = 20.
u(end) = u(end-1) + dx*qRight;

%% Crank-Nicolson coefficients
r = nu*dt/(2*dx^2);
s = alpha*dt/(4*dx);
k = c*dt/2;

A = spalloc(N, N, 3*N);
B = spalloc(N, N, 3*N);

%% Interior points
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

%% Left Dirichlet boundary: u(0,t) = sin^2(t)
A(1,1) = 1;
B(1,:) = 0;

%% Right Neumann boundary: du/dx = -0.2
% First-order backward difference:
%
% (u_N - u_{N-1})/dx = qRight
%
% Therefore:
%
% u_N - u_{N-1} = dx*qRight

A(N,N)   = 1;
A(N,N-1) = -1;
B(N,:)   = 0;

%% Times to store for final plot
snapshotTimes = [2 5 7 10 12 15 18 20];
snapshotSteps = round(snapshotTimes/dt);

snapshots = zeros(N, length(snapshotTimes));
snapshotCounter = 1;

%% Animation setup
figure;
h = plot(x, u, 'LineWidth', 2);
grid on;
xlabel('x [cm]');
ylabel('u(x,t)');
title('Drug concentration');
ylim([-0.1 1.2]);

%% Time stepping
for n = 0:Nt-1
    tNew = (n+1)*dt;

    rhs = B*u;

    % Apply boundary values at the new time level
    rhs(1) = leftBC(tNew);
    rhs(N) = dx*qRight;

    % Solve linear system
    u = A\rhs;

    % Store snapshots
    if snapshotCounter <= length(snapshotSteps) && n+1 == snapshotSteps(snapshotCounter)
        snapshots(:,snapshotCounter) = u;
        snapshotCounter = snapshotCounter + 1;
    end

    % Animate every few time steps
    if mod(n,5) == 0 || n == Nt-1
        set(h, 'YData', u);
        title(sprintf('Drug concentration, t = %.2f s', tNew));
        drawnow;
    end
end

%% Plot requested time profiles
figure;
plot(x, snapshots, 'LineWidth', 1.6);
grid on;
xlabel('x [cm]');
ylabel('u(x,t)');
title('Drug concentration at selected times');

legendLabels = arrayfun(@(tt) sprintf('t = %g s', tt), ...
    snapshotTimes, 'UniformOutput', false);

legend(legendLabels, 'Location', 'best');