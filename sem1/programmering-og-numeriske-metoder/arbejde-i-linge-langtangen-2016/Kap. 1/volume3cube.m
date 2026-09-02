% Vha. linspace findes 3 jævnt fordelte punkter i intervallet [1,3]

L = linspace(1,3,3);

% "Power of 3"-funktionen bruges på arrayet

V = L.^3;

% Resultatet printes med fprintf

fprintf("Volumen = %d \n", V)

% Funktionen plottes

plot(L, V);
xlabel("Sidelængde");
ylabel("Volumen")