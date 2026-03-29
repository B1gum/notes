function Y = ODEsRK4(ODEfun,Y0,t)
% Runge-Kutta 4th order solution of a system of ODE's.
%
% INPUTS:   ODEfun = function returning the values of ODE functions (column vector)
%           Y0     = Initial conditions (column vector)
%           t      = Time [t_0; t_1; t_2; ...; t_n]
%
% OUTPUTS:  Y         = Matrix with resulting function values over time
%           Y(i,n)    = i'th function value at n'th timestep, i.e. each
%                       column contains all function values for that time

% get size of problem
nEq = length(Y0);       % number of equations
nt  = length(t);        % number of timesteps
       

% initialize output
Y = zeros(nEq , nt);
Y(:,1) = Y0;            % store initial values column-wise

% marching forward through time
for n = 1:nt-1
    % current time step length (may vary)
    h = t(n+1)-t(n);

    % get intermediate values    
    k1 = h*ODEfun(Y(:,n),        t(n));
    k2 = h*ODEfun(Y(:,n)+0.5*k1, t(n)+h/2);
    k3 = h*ODEfun(Y(:,n)+0.5*k2, t(n)+h/2);
    k4 = h*ODEfun(Y(:,n)+k3,     t(n)+h);

    Y(:,n+1) = Y(:,n) + 1/6*k1 + 1/3*(k2+k3) + 1/6*k4;
    
end