function mat = MatLib(mode)
    arguments
        mode (1,1) string
    end
    
    switch lower(mode)
        case "micro"
            mat = microMaterials();
        case "macro"
            mat = macroMaterials();
        otherwise
            error('MatLib:InvalidMode', ...
                'Mode must be "Micro" or "Macro".');
    end
end


function mat = microMaterials()
    mat.Graphite.name = "Graphite fibre";
    mat.Graphite.E1 = 230e9;
    mat.Graphite.E2 = 22e9;
    mat.Graphite.nu12 = 0.30;
    mat.Graphite.nu23 = 0.35;
    mat.Graphite.G12 = 22e9;
    mat.Graphite.alpha1 = -1.3e-6;
    mat.Graphite.alpha2 = 7e-6;
    mat.Graphite.Xt = 2067e6;
    mat.Graphite.Xc = 1999e6;
    mat.Graphite.Yt = 77e6;
    mat.Graphite.Yc = 42e6;
    mat.Graphite.S = 36e6;
    mat.Graphite.sg = 1.8;

    mat.Glass.name = "Glass fibre";
    mat.Glass.E1 = 85e9;
    mat.Glass.E2 = 85e9;
    mat.Glass.nu12 = 0.20;
    mat.Glass.nu23 = 0.20;
    mat.Glass.G12 = 35.42e9;
    mat.Glass.alpha1 = 5e-6;
    mat.Glass.alpha2 = 5e-6;
    mat.Glass.Xt = 1550e6;
    mat.Glass.Xc = 1550e6;
    mat.Glass.Yt = 1550e6;
    mat.Glass.Yc = 1550e6;
    mat.Glass.S = 35e6;
    mat.Glass.sg = 2.5;

    mat.Aramid.name = "Aramid fibre";
    mat.Aramid.E1 = 124e9;
    mat.Aramid.E2 = 8e9;
    mat.Aramid.nu12 = 0.36;
    mat.Aramid.nu23 = 0.37;
    mat.Aramid.G12 = 3e9;
    mat.Aramid.alpha1 = -5e-6;
    mat.Aramid.alpha2 = 4.1e-6;
    mat.Aramid.Xt = 1379e6;
    mat.Aramid.Xc = 276e6;
    mat.Aramid.Yt = 7e6;
    mat.Aramid.Yc = 7e6;
    mat.Aramid.S = 21e6;
    mat.Aramid.sg = 1.4;

    mat.Epoxy.name = "Epoxy";
    mat.Epoxy.E1 = 3.4e9;
    mat.Epoxy.E2 = 3.4e9;
    mat.Epoxy.nu12 = 0.30;
    mat.Epoxy.nu23 = 0.30;
    mat.Epoxy.G12 = 1.308e9;
    mat.Epoxy.alpha = 63e-6;
    mat.Epoxy.beta = 0.33; %Coefficient of moisture expansion
    mat.Epoxy.Xt = 72e6;
    mat.Epoxy.Xc = 102e6;
    mat.Epoxy.Yt = 72e6;
    mat.Epoxy.Yc = 102e6;
    mat.Epoxy.S = 34e6;
    mat.Epoxy.sg = 1.2;

    mat.Aluminum.name = "Aluminum";
    mat.Aluminum.E1 = 71e9;
    mat.Aluminum.E2 = 71e9;
    mat.Aluminum.nu12 = 0.30;
    mat.Aluminum.nu23 = 0.30;
    mat.Aluminum.G12 = 27e9;
    mat.Aluminum.alpha = 23e-6;
    mat.Aluminum.beta = 0.00; %Coefficient of moisture expansion
    mat.Aluminum.Xt = 276e6;
    mat.Aluminum.Xc = 276e6;
    mat.Aluminum.Yt = 276e6;
    mat.Aluminum.Yc = 276e6;
    mat.Aluminum.S = 138e6;
    mat.Aluminum.sg = 2.7;

    mat.Polyamide.name = "Polyamide";
    mat.Polyamide.E1 = 3.5e9;
    mat.Polyamide.E2 = 3.5e9;
    mat.Polyamide.nu12 = 0.35;
    mat.Polyamide.nu23 = 0.35;
    mat.Polyamide.G12 = 1.3e9;
    mat.Polyamide.alpha = 90e-6;
    mat.Polyamide.beta = 0.33; %Coefficient of moisture expansion
    mat.Polyamide.Xt = 54e6;
    mat.Polyamide.Xc = 108e6;
    mat.Polyamide.Yt = 54e6;
    mat.Polyamide.Yc = 108e6;
    mat.Polyamide.S = 54e6;
    mat.Polyamide.sg = 1.2;
end


function mat = macroMaterials()
    mat.Aluminium.name = "Aluminium";
    mat.Aluminium.E1 = 68e9;
    mat.Aluminium.E2 = 68e9;
    mat.Aluminium.E3 = 68e9;
    mat.Aluminium.G12 = 25.5e9;
    mat.Aluminium.G13 = 25.5e9;
    mat.Aluminium.G23 = 25.5e9;
    mat.Aluminium.nu12 = 0.33;
    mat.Aluminium.nu13 = 0.33;
    mat.Aluminium.nu23 = 0.33;
    
    mat.Steel.name = "Steel";
    mat.Steel.E1 = 207e9;
    mat.Steel.E2 = 207e9;
    mat.Steel.E3 = 207e9;
    mat.Steel.G12 = 77.5e9;
    mat.Steel.G13 = 77.5e9;
    mat.Steel.G23 = 77.5e9;
    mat.Steel.nu12 = 0.29;
    mat.Steel.nu13 = 0.29;
    mat.Steel.nu23 = 0.29;
    
    mat.CF_Ep.name = "CF-Ep.";
    mat.CF_Ep.E1 = 137e9;
    mat.CF_Ep.E2 = 9.0e9;
    mat.CF_Ep.E3 = 8.9e9;
    mat.CF_Ep.G12 = 7.1e9;
    mat.CF_Ep.G13 = 7.1e9;
    mat.CF_Ep.G23 = 6.2e9;
    mat.CF_Ep.nu12 = 0.30;
    mat.CF_Ep.nu13 = 0.30;
    mat.CF_Ep.nu23 = 0.49;
    
    mat.GF_Ep.name = "GF-Ep.";
    mat.GF_Ep.E1 = 53.8e9;
    mat.GF_Ep.E2 = 17.9e9;
    mat.GF_Ep.E3 = 17.9e9;
    mat.GF_Ep.G12 = 9.0e9;
    mat.GF_Ep.G13 = 9.0e9;
    mat.GF_Ep.G23 = 3.4e9;
    mat.GF_Ep.nu12 = 0.26;
    mat.GF_Ep.nu13 = 0.25;
    mat.GF_Ep.nu23 = 0.34;
    
    mat.BF_Ep.name = "BF-Ep.";
    mat.BF_Ep.E1 = 206.9e9;
    mat.BF_Ep.E2 = 20.7e9;
    mat.BF_Ep.E3 = 20.7e9;
    mat.BF_Ep.G12 = 6.9e9;
    mat.BF_Ep.G13 = 6.9e9;
    mat.BF_Ep.G23 = 4.1e9;
    mat.BF_Ep.nu12 = 0.30;
    mat.BF_Ep.nu13 = 0.25;
    mat.BF_Ep.nu23 = 0.25;
end