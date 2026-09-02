clear all; close all; clc

%% Kendt data
dof=2;
EI=10;
L=1.2^(1/3);
k=12*EI/L^3;
m=1.5;
zeta=[0.05 ; 0.05];
F0=[0 ; 4];
Omega=5.5;

%% Indledende systemmodellering
K=2*[k -k ; -k 2*k];
M=m*eye(dof);
[Phi,Lambda]=eig(K,M);
omegaN=sqrt(diag(Lambda));
[omegaN,i2]=sort(omegaN);
Phi=Phi(:,i2);
Phi=Phi./Phi(1,:);

%% Tidsdefinition for at facilitere beregningerne
N=3000;
dt=0.001;
t=0:dt:(N-1)*dt;

%% a) Dæmpningsmatricen
Mtilde=Phi'*M*Phi;
Ctilde=diag(2.*zeta.*diag(Mtilde).*omegaN);
C=(Phi')^-1*Ctilde*Phi^-1;

%% b) Systemrespons via modaldekobling
Ktilde=Phi'*K*Phi;
F=F0*cos(Omega*t);
Ftilde=Phi'*F;
qp=zeros(dof,N);
for jj=1:dof
    Bj=Ftilde(jj,1)/sqrt((Ktilde(jj,jj)-Mtilde(jj,jj)*Omega^2)^2+Ctilde(jj,jj)^2*Omega^2);
    epsj=atan2(Ctilde(jj,jj)*Omega,(Ktilde(jj,jj)-Mtilde(jj,jj)*Omega^2));
    qp(jj,:)=Bj*cos(Omega*t-epsj);
end
dp=Phi*qp;

%% c) Systemrespons via modaltrunkering;
ModeKeep=1; % Vi bevarer den første egensvingningskonfiguration
dpTr=Phi(:,ModeKeep)*qp(ModeKeep,:);

%% d) Systemrespons via Fourier-transformation
H=(-M*Omega^2+C*Omega*1i+K)^-1;
Dss=H*F0;
B=abs(Dss);
eps=-angle(Dss);
dpFo=B.*cos(Omega*t-eps);

%% Visualisering af resultater
figure; plot(t,dp(1,:),'k-',t,dpTr(1,:),'k-.',t(1:10:end),dpFo(1,1:10:end),'r.')
xlabel('Tid (s)'); ylabel('Flytning (m) i DOF 1')
legend('Modaldekobling','Modaldekobling m. trunkering','Fouriertransformation')

figure; plot(t,dp(2,:),'k-',t,dpTr(2,:),'k-.',t(1:10:end),dpFo(2,1:10:end),'r.')
xlabel('Tid (s)'); ylabel('Flytning (m) i DOF 2')
legend('Modaldekobling','Modaldekobling m. trunkering','Fouriertransformation')
