function lamina = MatPropLamina(fiber, matrix, Vf)
    Vm = 1 - Vf;
    
    lamina.E1 = Vf * fiber.E1 + Vm * matrix.E1;
    
    lamina.E2 = (fiber.E1 * matrix.E1) / (matrix.E1 * Vf + fiber.E1 * Vm);
    
    lamina.nu12 = matrix.nu12 * Vm + fiber.nu12 * Vf;
    
    lamina.G12 = (matrix.G12 * fiber.G12) / (Vm * fiber.G12 + Vf * matrix.G12);
    
    lamina.alpha1 = (fiber.alpha1 * fiber.E1 / lamina.E1) * Vf + (matrix.alpha * matrix.E1 / lamina.E1) * Vm;
    
    lamina.alpha2 = (1 + fiber.nu12) * fiber.alpha1 * Vf + ...
        (1 + matrix.nu12) * matrix.alpha * Vm - ...
        lamina.alpha1 * lamina.nu12;

    lamina.E_CSM = 3/8 * lamina.E1 + 5/8 * lamina.E2;
    lamina.G_CSM = 1/8 * lamina.E1 + 1/4 * lamina.E2;
    lamina.nu_CSM = (lamina.E1 + lamina.E2)/(2 * lamina.E1 + 4 * lamina.E2);
    lamina.alpha_CSM = (lamina.alpha1 + lamina.alpha2)/2 + (lamina.E1 - lamina.E2)/(lamina.E1 + (1 + 2 * lamina.nu12) * lamina.E2) * (lamina.alpha1 - lamina.alpha2)/2;
end