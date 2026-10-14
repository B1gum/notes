function PlotThermalExp(fiber, matrix)
    Vf = linspace(0,1,101);

    alpha_1 = zeros(size(Vf));
    alpha_2 = zeros(size(Vf));

    for i = 1:length(Vf)
        lamina = MatPropLamina(fiber, matrix, Vf(i));
        alpha_1(i) = lamina.alpha1;
        alpha_2(i) = lamina.alpha2;
    end

    figure
    plot(Vf, alpha_1)
    hold on
    plot(Vf, alpha_2)
    xlabel("Fibre Volume Fraction, $V_f$", "Interpreter", "latex")
    ylabel("$\alpha_1 \left[ \frac{1}{\mathrm{K}} \right]$", "Interpreter", "latex") 
    legend("$\alpha_1$", "$\alpha_2$", "Interpreter", "latex")
    grid on
    hold off
end