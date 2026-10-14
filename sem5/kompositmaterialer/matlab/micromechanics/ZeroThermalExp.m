function [Vf_zero, lamina] = ZeroThermalExp(fiber, matrix)
    alpha_1 = 0;
    
    Ef = fiber.E1;
    Em = matrix.E1;
    
    alpha_f = fiber.alpha1;
    alpha_m = matrix.alpha;
    
    % Fibre volume fraction required for specified alpha_1
    Vf_zero = ...
        Em * (alpha_m - alpha_1) / ...
        (alpha_1 * (Ef - Em) - Ef * alpha_f + Em * alpha_m);
    
    % Check that the result represents a physical volume fraction
    if Vf_zero < 0 || Vf_zero > 1
        warning("Computed fibre volume fraction %.4f is outside [0,1].", Vf_zero);
    end
    
    % Compute all lamina properties using this volume fraction
    lamina = MatPropLamina(fiber, matrix, Vf_zero);
end