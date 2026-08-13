%% F3 - DIMENSIONERING AF CYLINDRISK TRYKSKRUEFJEDER
% Brug dette script naar en lineær cylindrisk trykskruefjeder med rund tråd
% skal dimensioneres ud fra kraftinterval, deformation, spænding og geometri.
%
% Brug ikke dette script til kontrol af en allerede kendt fjeder (brug F2),
% eller til udmattelse, knækning, dynamik, koniske fjedre eller tallerkenfjedre.
%
% Manuelt før beregning:
% - slå G og tilladelig forskydningsspænding op;
% - indsæt faktisk tilgængelige standardmål for d, D og N_a;
% - bestem endetype/inaktive vindinger, hvis bloklængde skal kontrolleres.
%
% Kursusmetode:
% C = D/d
% K_B = (4*C+2)/(4*C-3)
% k = d^4*G/(8*D^3*N_a)
% delta = F/k
% tau = K_B*8*F*D/(pi*d^3)
%
% Enheder: N, mm, N/mm og MPa. Ingen toolbox nødvendig.

clearvars
clc
close all

%% ASSUMPTIONS AND MANUAL INPUT
% Lineær, aksialt belastet trykskruefjeder med rund tråd.
% D er middeldiameteren. Bergsträsser-faktoren anvendes.
% Kandidatlisterne skal komme fra opgaven eller et katalog.
% Statisk spændingskontrol erstatter ikke en udmattelsesberegning.

%% INPUT
forceRange = [0, 100];              % [N] [F_min F_max]
requiredDeflectionChange = 10;      % [mm] Krævet delta_max-delta_min
stiffnessToleranceRelative = 0.05;  % [-] Tilladt relativ fejl på k

shearModulus = 81e3;                % [MPa] G, DEMO - erstat med materialedata
allowableShearStress = 500;         % [MPa] DEMO - erstat med opgavens værdi

% DEMONSTRATIONSGRID - IKKE en katalog-/standardserie:
wireDiameterCandidates = [2.00 2.25 2.50 3.00]; % [mm] mulige d
meanDiameterCandidates = [10 12 14 16 18];      % [mm] mulige D
activeCoilCandidates = 3:15;                    % [-] mulige N_a

springIndexLimits = [4 12];         % [-] kursusinterval for C
activeCoilLimits = [3 15];          % [-] Shigley-interval i kursusnoterne
enforceActiveCoilLimits = true;     % [-] false kun med faglig begrundelse

% Valgfrie geometriske krav. NaN betyder "ikke kontrolleret".
maximumOutsideDiameter = NaN;       % [mm] maks. D_o = D+d
minimumInsideDiameter = NaN;        % [mm] min. D_i = D-d
maximumWorkingDeflection = NaN;     % [mm] maks. delta ved F_max
maximumFreeLength = NaN;            % [mm] maks. tilladt fri længde L_0
maximumSolidLength = NaN;           % [mm] maks. bloklængde L_s
inactiveCoils = NaN;                % [-] fra endetype/tegning
minimumClashAllowance = 0;          % [mm] reserve før bloklængde

referenceSpringIndex = 6;           % [-] C til kontinuerligt overslag
referenceActiveCoils = 10;          % [-] N_a til kontinuerligt overslag

numberOfCandidatesToShow = 10;      % [-]
makePlots = true;                   % [-]
runTests = true;                    % [-]
testTolerance = 1e-9;               % [-]

%% UNIT CHECK AND VALIDATION
assert(isnumeric(forceRange) && numel(forceRange)==2 && ...
    all(isfinite(forceRange)) && forceRange(1)>=0 && ...
    forceRange(2)>forceRange(1), ...
    'forceRange skal være [F_min F_max], hvor 0 <= F_min < F_max.')

assert(isscalar(requiredDeflectionChange) && ...
    isfinite(requiredDeflectionChange) && requiredDeflectionChange>0, ...
    'requiredDeflectionChange skal være positiv [mm].')

assert(isscalar(stiffnessToleranceRelative) && ...
    stiffnessToleranceRelative>=0 && stiffnessToleranceRelative<1, ...
    'stiffnessToleranceRelative skal ligge i [0,1).')

assert(isscalar(shearModulus) && isfinite(shearModulus) && ...
    shearModulus>0, 'shearModulus skal være positiv [MPa].')

assert((isscalar(allowableShearStress) && isnan(allowableShearStress)) || ...
    (isscalar(allowableShearStress) && ...
    isfinite(allowableShearStress) && allowableShearStress>0), ...
    'allowableShearStress skal være positiv [MPa] eller NaN.')

validatePositiveVector(wireDiameterCandidates,'wireDiameterCandidates')
validatePositiveVector(meanDiameterCandidates,'meanDiameterCandidates')
validatePositiveVector(activeCoilCandidates,'activeCoilCandidates')

assert(numel(springIndexLimits)==2 && springIndexLimits(1)>0.75 && ...
    springIndexLimits(2)>springIndexLimits(1), ...
    'springIndexLimits skal være [C_min C_max].')

assert(numel(activeCoilLimits)==2 && activeCoilLimits(1)>0 && ...
    activeCoilLimits(2)>=activeCoilLimits(1), ...
    'activeCoilLimits skal være [N_min N_max].')

validateOptionalNonnegative(maximumOutsideDiameter,'maximumOutsideDiameter')
validateOptionalNonnegative(minimumInsideDiameter,'minimumInsideDiameter')
validateOptionalNonnegative(maximumWorkingDeflection,'maximumWorkingDeflection')
validateOptionalNonnegative(maximumFreeLength,'maximumFreeLength')
validateOptionalNonnegative(maximumSolidLength,'maximumSolidLength')
validateOptionalNonnegative(inactiveCoils,'inactiveCoils')
validateOptionalNonnegative(minimumClashAllowance,'minimumClashAllowance')

assert(referenceSpringIndex>0.75 && referenceActiveCoils>0, ...
    'Referenceværdierne C og N_a skal være positive.')
assert(numberOfCandidatesToShow>=1 && ...
    mod(numberOfCandidatesToShow,1)==0, ...
    'numberOfCandidatesToShow skal være et positivt heltal.')

%% CALCULATION
input.forceRange = forceRange;
input.requiredDeflectionChange = requiredDeflectionChange;
input.stiffnessToleranceRelative = stiffnessToleranceRelative;
input.shearModulus = shearModulus;
input.allowableShearStress = allowableShearStress;
input.dCandidates = wireDiameterCandidates;
input.DCandidates = meanDiameterCandidates;
input.NaCandidates = activeCoilCandidates;
input.springIndexLimits = springIndexLimits;
input.activeCoilLimits = activeCoilLimits;
input.enforceActiveCoilLimits = enforceActiveCoilLimits;
input.maximumOutsideDiameter = maximumOutsideDiameter;
input.minimumInsideDiameter = minimumInsideDiameter;
input.maximumWorkingDeflection = maximumWorkingDeflection;
input.maximumFreeLength = maximumFreeLength;
input.maximumSolidLength = maximumSolidLength;
input.inactiveCoils = inactiveCoils;
input.minimumClashAllowance = minimumClashAllowance;
input.referenceSpringIndex = referenceSpringIndex;
input.referenceActiveCoils = referenceActiveCoils;

results = designSpring(input);

%% RESULTS
fprintf('\n================ F3 RESULTATER ================\n')
fprintf('Krævet fjederkonstant k_req : %.6g N/mm\n',results.kRequired)
fprintf('Undersøgte kombinationer    : %d\n',height(results.allCandidates))
fprintf('Godkendte kandidater        : %d\n',height(results.feasibleCandidates))

fprintf('\nKontinuerligt overslag ved C=%.4g og N_a=%.4g:\n', ...
    referenceSpringIndex,referenceActiveCoils)
fprintf('d_kont = %.6g mm\n',results.continuous.d)
fprintf('D_kont = %.6g mm\n',results.continuous.D)
fprintf('tau_max,kont = %.6g MPa\n',results.continuous.tauMax)

if results.hasCandidate
    nShow = min(numberOfCandidatesToShow,height(results.feasibleCandidates));
    fprintf('\nBedste kandidater fra de LEVEREDE lister:\n')
    disp(results.feasibleCandidates(1:nShow,:))

    selected = results.selected;
    fprintf('\nValgt kandidat:\n')
    fprintf('d = %.6g mm, D = %.6g mm, N_a = %.6g\n', ...
        selected.d_mm,selected.D_mm,selected.Na)
    fprintf('C = %.6g, K_B = %.6g\n',selected.C,selected.KB)
    fprintf('k = %.6g N/mm (fejl %.3f %%)\n', ...
        selected.k_N_pr_mm,100*selected.k_rel_fejl)
    fprintf('delta_min = %.6g mm, delta_max = %.6g mm\n', ...
        selected.delta_min_mm,selected.delta_max_mm)
    fprintf('tau_max = %.6g MPa\n',selected.tau_max_MPa)
    fprintf('D_i = %.6g mm, D_o = %.6g mm\n', ...
        selected.Di_mm,selected.Do_mm)

    if results.lengthKnown
        fprintf('L_s = %.6g mm, nødvendigt L_0,min = %.6g mm\n', ...
            selected.Ls_mm,selected.L0_min_mm)
    end
else
    fprintf('\nIKKE OK: Ingen kombination opfylder alle aktiverede krav.\n')
    fprintf('Nærmeste kandidater (ikke godkendte):\n')
    disp(results.closestCandidates(1:min(numberOfCandidatesToShow, ...
        height(results.closestCandidates)),:))
end

%% AUTOMATIC CHECKS
if isnan(allowableShearStress)
    fprintf(['ADVARSEL: Tilladelig spænding mangler. ' ...
        'Kandidaterne er ikke styrkegodkendte.\n'])
else
    fprintf('OK: Statisk spændingskrav indgår i udvælgelsen.\n')
end

if results.hasCandidate
    fprintf('OK: Mindst én kandidat opfylder alle aktiverede krav.\n')
else
    fprintf(['IKKE OK: Udvid de leverede kandidatlister eller revider kravene. ' ...
        'Katalogværdier må ikke gættes.\n'])
end

if isnan(inactiveCoils)
    fprintf(['ADVARSEL: Blok-/fri-længde er ikke fuldt kontrolleret, ' ...
        'fordi inactiveCoils mangler.\n'])
end

fprintf(['ADVARSEL: Knækning, udmattelse, egenfrekvens, tolerancer og ' ...
    'fjederender skal kontrolleres separat, hvis opgaven kræver det.\n'])

%% PLOTS
if makePlots
    T = results.allCandidates;

    figure('Name','F3 - kandidater')
    scatter(T.k_N_pr_mm,T.tau_max_MPa,36,T.C,'filled')
    hold on
    xline(results.kRequired,'--','k_{req}')
    xline(results.kRequired*(1-stiffnessToleranceRelative),':')
    xline(results.kRequired*(1+stiffnessToleranceRelative),':')
    if ~isnan(allowableShearStress)
        yline(allowableShearStress,'--','\tau_{till}')
    end
    if results.hasCandidate
        scatter(results.selected.k_N_pr_mm,results.selected.tau_max_MPa, ...
            100,'d','LineWidth',1.5)
    end
    hold off
    xlabel('Fjederkonstant k [N/mm]')
    ylabel('Maksimal forskydningsspænding \tau_{max} [MPa]')
    title('Undersøgte fjederkandidater')
    colorbar
    grid on

    if results.hasCandidate
        Fplot = linspace(0,forceRange(2),200);
        deltaPlot = Fplot/results.selected.k_N_pr_mm;

        figure('Name','F3 - valgt karakteristik')
        plot(deltaPlot,Fplot,'LineWidth',1.5)
        hold on
        scatter([results.selected.delta_min_mm ...
            results.selected.delta_max_mm],forceRange,50,'filled')
        hold off
        xlabel('Deformation \delta [mm]')
        ylabel('Kraft F [N]')
        title('Kraft-deformationslinje for valgt kandidat')
        legend('F=k\delta','Driftspunkter','Location','best')
        grid on
    end
end

%% PHYSICAL CONCLUSION
fprintf('\n================ FYSISK KONKLUSION ================\n')
if results.hasCandidate
    selected = results.selected;
    fprintf(['Kandidaten d=%.4g mm, D=%.4g mm og N_a=%.4g giver ' ...
        'k=%.4g N/mm og en deformationsændring på %.4g mm.\n'], ...
        selected.d_mm,selected.D_mm,selected.Na, ...
        selected.k_N_pr_mm, ...
        selected.delta_max_mm-selected.delta_min_mm)
    fprintf(['Maksimal statisk Bergsträsser-korrigeret spænding er ' ...
        '%.4g MPa. Det valgte praktiske mål kommer fra de leverede lister; ' ...
        'det kontinuerlige resultat må ikke afrundes til en opdigtet standard.\n'], ...
        selected.tau_max_MPa)
else
    fprintf(['Ingen leveret kombination opfylder kravene. Det kan skyldes ' ...
        'uforenelige krav eller for få katalogkandidater.\n'])
end

%% OPTIONAL TEST CASES
% 1) Omvendt regression mod kursusopgave 2.1.
% 2) Håndkontrol: d=2, D=10, N_a=10, G=80000 giver k=16 N/mm.
% 3) Fejltilfælde med for lav tilladelig spænding.
if runTests
    testReport = runF3Tests(testTolerance);
    disp(testReport)
    assert(all(testReport.Bestaaet), ...
        'Mindst én F3-test fejlede. Se testReport.')
    fprintf('OK: Alle F3-tests består.\n')
end

%% LOCAL FUNCTIONS
function results = designSpring(in)
    Fmin = in.forceRange(1);
    Fmax = in.forceRange(2);
    kRequired = (Fmax-Fmin)/in.requiredDeflectionChange;

    % Kontinuerligt overslag: D=C*d indsat i stivhedsformlen.
    Cref = in.referenceSpringIndex;
    Nref = in.referenceActiveCoils;
    dCont = 8*Cref^3*Nref*kRequired/in.shearModulus;
    DCont = Cref*dCont;
    KBCont = (4*Cref+2)/(4*Cref-3);
    tauCont = KBCont*8*Fmax*DCont/(pi*dCont^3);

    [dGrid,DGrid,NaGrid] = ndgrid( ...
        in.dCandidates,in.DCandidates,in.NaCandidates);

    d = dGrid(:);
    D = DGrid(:);
    Na = NaGrid(:);

    C = D./d;
    KB = (4*C+2)./(4*C-3);
    k = d.^4*in.shearModulus./(8*D.^3.*Na);

    deltaMin = Fmin./k;
    deltaMax = Fmax./k;
    tauMax = KB.*8*Fmax.*D./(pi*d.^3);
    Di = D-d;
    Do = D+d;
    kError = abs(k-kRequired)/kRequired;

    C_OK = C>=in.springIndexLimits(1) & C<=in.springIndexLimits(2);
    Na_interval_OK = Na>=in.activeCoilLimits(1) & ...
        Na<=in.activeCoilLimits(2);
    if in.enforceActiveCoilLimits
        Na_OK = Na_interval_OK;
    else
        Na_OK = true(size(Na));
    end

    k_OK = kError<=in.stiffnessToleranceRelative;

    if isnan(in.allowableShearStress)
        tauUtil = NaN(size(tauMax));
        tau_OK = true(size(tauMax));
    else
        tauUtil = tauMax/in.allowableShearStress;
        tau_OK = tauMax<=in.allowableShearStress;
    end

    Do_OK = optionalUpper(Do,in.maximumOutsideDiameter);
    Di_OK = optionalLower(Di,in.minimumInsideDiameter);
    delta_OK = optionalUpper(deltaMax,in.maximumWorkingDeflection);

    lengthKnown = ~isnan(in.inactiveCoils);
    if lengthKnown
        Nt = Na+in.inactiveCoils;
        Ls = Nt.*d;
        L0min = Ls+deltaMax+in.minimumClashAllowance;
        Ls_OK = optionalUpper(Ls,in.maximumSolidLength);
        L0_OK = optionalUpper(L0min,in.maximumFreeLength);
    else
        Nt = NaN(size(Na));
        Ls = NaN(size(Na));
        L0min = NaN(size(Na));
        Ls_OK = true(size(Na));
        L0_OK = true(size(Na));
    end

    feasible = C_OK & Na_OK & k_OK & tau_OK & ...
        Do_OK & Di_OK & delta_OK & Ls_OK & L0_OK;

    T = table(d,D,Na,C,KB,k,kError,deltaMin,deltaMax,tauMax,tauUtil, ...
        Di,Do,Nt,Ls,L0min,C_OK,Na_interval_OK,k_OK,tau_OK, ...
        Do_OK,Di_OK,delta_OK,Ls_OK,L0_OK,feasible, ...
        'VariableNames',{'d_mm','D_mm','Na','C','KB','k_N_pr_mm', ...
        'k_rel_fejl','delta_min_mm','delta_max_mm','tau_max_MPa', ...
        'spaendingsudnyttelse','Di_mm','Do_mm','Nt','Ls_mm','L0_min_mm', ...
        'C_OK','Na_interval_OK','k_OK','tau_OK','Do_OK','Di_OK', ...
        'delta_OK','Ls_OK','L0_OK','samlet_OK'});

    if isnan(in.allowableShearStress)
        stressRank = tauMax/max(tauMax);
    else
        stressRank = tauUtil;
    end
    T.stressRank = stressRank;

    feasibleT = T(feasible,:);
    if ~isempty(feasibleT)
        feasibleT = sortrows(feasibleT, ...
            {'k_rel_fejl','stressRank','Do_mm','d_mm'}, ...
            {'ascend','ascend','ascend','ascend'});
        selected = feasibleT(1,:);
        hasCandidate = true;
    else
        selected = T([],:);
        hasCandidate = false;
    end

    violations = ~C_OK + ~Na_OK + ~k_OK + ~tau_OK + ...
        ~Do_OK + ~Di_OK + ~delta_OK + ~Ls_OK + ~L0_OK;
    T.antal_brudte_krav = violations;
    closest = sortrows(T, ...
        {'antal_brudte_krav','k_rel_fejl','tau_max_MPa'}, ...
        {'ascend','ascend','ascend'});

    results.kRequired = kRequired;
    results.continuous = struct('d',dCont,'D',DCont,'C',Cref, ...
        'Na',Nref,'KB',KBCont,'tauMax',tauCont);
    results.allCandidates = T;
    results.feasibleCandidates = feasibleT;
    results.closestCandidates = closest;
    results.selected = selected;
    results.hasCandidate = hasCandidate;
    results.lengthKnown = lengthKnown;
end

function report = runF3Tests(tol)
    names = ["Kursusopgave 2.1 - omvendt regression"; ...
             "Simpel håndkontrol"; ...
             "Fejltilfælde - for lav tau_till"];
    calculated = strings(3,1);
    maxRelativeError = zeros(3,1);
    passed = false(3,1);

    % Kursusopgave 2.1: d=2.25, D=11.7, Na=21, G=81000.
    d = 2.25; D = 11.7; Na = 21; G = 81e3;
    F = [25 156];
    kExpected = d^4*G/(8*D^3*Na);

    in = baseTestInput();
    in.forceRange = F;
    in.requiredDeflectionChange = diff(F)/kExpected;
    in.shearModulus = G;
    in.dCandidates = d;
    in.DCandidates = D;
    in.NaCandidates = Na;
    in.activeCoilLimits = [3 25]; % kun for denne regression
    in.referenceSpringIndex = D/d;
    in.referenceActiveCoils = Na;

    r = designSpring(in);
    s = r.selected;

    expected = [2.25 11.7 21 5.2 1.280898876404494 ...
        7.715218398465441 3.240348971193415 ...
        20.21977758024691 522.6583159076253];

    actual = [s.d_mm s.D_mm s.Na s.C s.KB s.k_N_pr_mm ...
        s.delta_min_mm s.delta_max_mm s.tau_max_MPa];

    maxRelativeError(1) = maxRelError(actual,expected);
    passed(1) = r.hasCandidate && maxRelativeError(1)<=tol;
    calculated(1) = sprintf('k=%.6f, tau_max=%.6f', ...
        s.k_N_pr_mm,s.tau_max_MPa);

    % Håndkontrol: k=16 N/mm og delta=1 mm ved F=16 N.
    in = baseTestInput();
    in.forceRange = [0 16];
    in.requiredDeflectionChange = 1;
    in.shearModulus = 80e3;
    in.allowableShearStress = 1e6;
    in.dCandidates = 2;
    in.DCandidates = 10;
    in.NaCandidates = 10;

    r = designSpring(in);
    s = r.selected;
    expected = [16 1 5];
    actual = [s.k_N_pr_mm s.delta_max_mm s.C];

    maxRelativeError(2) = maxRelError(actual,expected);
    passed(2) = r.hasCandidate && maxRelativeError(2)<=tol;
    calculated(2) = sprintf('k=%.6f, delta=%.6f', ...
        s.k_N_pr_mm,s.delta_max_mm);

    % Samme kandidat afvises ved meget lav tilladelig spænding.
    in.allowableShearStress = 10;
    r = designSpring(in);
    passed(3) = ~r.hasCandidate && isempty(r.feasibleCandidates);
    calculated(3) = sprintf('godkendte=%d',height(r.feasibleCandidates));

    report = table(names,calculated,maxRelativeError,passed, ...
        'VariableNames',{'Test','Beregnet','MaksRelativFejl','Bestaaet'});
end

function in = baseTestInput()
    in.forceRange = [0 1];
    in.requiredDeflectionChange = 1;
    in.stiffnessToleranceRelative = 1e-10;
    in.shearModulus = 80e3;
    in.allowableShearStress = NaN;
    in.dCandidates = 1;
    in.DCandidates = 5;
    in.NaCandidates = 10;
    in.springIndexLimits = [4 12];
    in.activeCoilLimits = [3 15];
    in.enforceActiveCoilLimits = true;
    in.maximumOutsideDiameter = NaN;
    in.minimumInsideDiameter = NaN;
    in.maximumWorkingDeflection = NaN;
    in.maximumFreeLength = NaN;
    in.maximumSolidLength = NaN;
    in.inactiveCoils = NaN;
    in.minimumClashAllowance = 0;
    in.referenceSpringIndex = 5;
    in.referenceActiveCoils = 10;
end

function ok = optionalUpper(value,limit)
    if isnan(limit)
        ok = true(size(value));
    else
        ok = value<=limit;
    end
end

function ok = optionalLower(value,limit)
    if isnan(limit)
        ok = true(size(value));
    else
        ok = value>=limit;
    end
end

function value = maxRelError(actual,expected)
    value = max(abs(actual-expected)./max(1,abs(expected)));
end

function validatePositiveVector(value,name)
    assert(isnumeric(value) && isvector(value) && ~isempty(value) && ...
        all(isfinite(value)) && all(value>0), ...
        '%s skal være en ikke-tom vektor med positive værdier.',name)
end

function validateOptionalNonnegative(value,name)
    assert((isscalar(value) && isnan(value)) || ...
        (isscalar(value) && isfinite(value) && value>=0), ...
        '%s skal være ikke-negativ eller NaN.',name)
end
