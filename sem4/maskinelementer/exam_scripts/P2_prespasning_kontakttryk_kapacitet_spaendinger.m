%% P2 - PRESPASNING: KONTAKTTRYK, KAPACITET OG SPAENDINGER
% Brug dette script naar P1 har givet hullets og akslens graensemaal, og
% der skal findes kontakttryk, friktionskapacitet og Lame-spaendinger.
%
% Brug ikke scriptet til hul aksel, koniske/ikke-rotationssymmetriske
% samlinger, plastisk prespasning, temperaturmontage eller kanttryk.
%
% Kursusmodel: massiv aksel + tykvaegget nav, plane stress, linearelasticitet
% og kompatibiliteten u_h - u_a = Delta/2. Delta er DIAMETRALT overlap.
% Ved samme E og nu reducerer modellen til kursusformlen
%
% p = E*Delta*(b^2-a^2)/(4*a*b^2 + Delta*(b^2-a^2)*(1-nu)).
%
% Toleranceafvigelser, friktion og materialedata skal findes manuelt.

clear
clc
close all

%% ASSUMPTIONS AND MANUAL INPUT
% - a og b holdes ved nominelle vaerdier for alle tolerancekombinationer.
% - Kontakttrykket antages ensartet over hele kontaktlaengden.
% - Coulomb-friktion bruges til aksialkraft og moment.
% - Traekspaending er positiv; trykspaending er negativ.
% - Negativt algebraisk p betyder kontaktbrud, ikke fysisk undertryk.

%% INPUT
% Geometri og graensemaal fra P1
nominalBoreDiameter = 31.0;          % [mm] Nominel huldiameter, 2*a
hubOuterDiameter = 51.0;             % [mm] Navets ydre diameter, 2*b
contactLength = 10.0;                % [mm] Effektiv kontaktlaengde
hubBoreMinimumDiameter = 30.875;     % [mm] Mindste huldiameter
hubBoreMaximumDiameter = 31.125;     % [mm] Stoerste huldiameter
shaftMinimumDiameter = 34.875;       % [mm] Mindste akseldiameter
shaftMaximumDiameter = 35.125;       % [mm] Stoerste akseldiameter

% Materialedata
shaftElasticModulus = 200000;        % [MPa] Akslens elasticitetsmodul
shaftPoissonRatio = 0.30;            % [-] Akslens Poissons tal
hubElasticModulus = 200000;          % [MPa] Navets elasticitetsmodul
hubPoissonRatio = 0.30;              % [-] Navets Poissons tal
shaftYieldStrength = NaN;            % [MPa] NaN hvis ikke oplyst
hubYieldStrength = NaN;              % [MPa] NaN hvis ikke oplyst
minimumYieldSafetyFactor = 1.00;      % [-] Krav mod flydning

% Friktion og belastningskrav
frictionCoefficient = NaN;           % [-] NaN hvis ikke oplyst
capacitySafetyFactor = 1.00;          % [-] Sikkerhed paa kapacitet
requiredAxialForce = NaN;             % [N] NaN hvis intet krav
requiredTorque = NaN;                 % [N*m] NaN hvis intet krav

% Kontroller og figurer
smallStrainWarningLimit = 0.01;       % [-] Valgt graense for lille deformation
makeStressPlot = true;                % [-] Plot spaendinger i navet
makePressurePlot = true;              % [-] Plot p som funktion af Delta
runOptionalTestCases = true;          % [-] Koer regressionstest

%% UNIT CHECK AND VALIDATION
geometry = [nominalBoreDiameter, hubOuterDiameter, contactLength, ...
    hubBoreMinimumDiameter, hubBoreMaximumDiameter, ...
    shaftMinimumDiameter, shaftMaximumDiameter];

assert(all(isfinite(geometry)) && all(geometry > 0), ...
    'Alle geometriske input skal vaere positive og endelige.');
assert(hubOuterDiameter > nominalBoreDiameter, ...
    'Navets ydre diameter skal vaere stoerre end huldiameteren.');
assert(hubBoreMaximumDiameter >= hubBoreMinimumDiameter, ...
    'Hullets maksimumdiameter skal vaere >= minimumdiameteren.');
assert(shaftMaximumDiameter >= shaftMinimumDiameter, ...
    'Akslens maksimumdiameter skal vaere >= minimumdiameteren.');
assert(shaftElasticModulus > 0 && hubElasticModulus > 0, ...
    'Elasticitetsmoduler skal vaere positive.');
assert(shaftPoissonRatio >= 0 && shaftPoissonRatio < 0.5, ...
    'Akslens Poissons tal skal ligge i intervallet [0;0.5).');
assert(hubPoissonRatio >= 0 && hubPoissonRatio < 0.5, ...
    'Navets Poissons tal skal ligge i intervallet [0;0.5).');
assert(isnan(shaftYieldStrength) || shaftYieldStrength > 0, ...
    'Akslens flydespaending skal vaere positiv eller NaN.');
assert(isnan(hubYieldStrength) || hubYieldStrength > 0, ...
    'Navets flydespaending skal vaere positiv eller NaN.');
assert(isnan(frictionCoefficient) || ...
    (frictionCoefficient >= 0 && frictionCoefficient <= 1), ...
    'Friktionskoefficienten skal ligge i [0;1] eller vaere NaN.');
assert(capacitySafetyFactor >= 1 && minimumYieldSafetyFactor > 0, ...
    'Sikkerhedsfaktorerne er ugyldige.');
assert(isnan(requiredAxialForce) || requiredAxialForce >= 0, ...
    'Kraevet aksialkraft skal vaere ikke-negativ eller NaN.');
assert(isnan(requiredTorque) || requiredTorque >= 0, ...
    'Kraevet moment skal vaere ikke-negativt eller NaN.');
assert(smallStrainWarningLimit > 0, ...
    'smallStrainWarningLimit skal vaere positiv.');

%% CALCULATION - OVERLAP AND CONTACT PRESSURE
a = nominalBoreDiameter/2;           % [mm] Nominel kontaktradius
b = hubOuterDiameter/2;              % [mm] Navets ydre radius

minimumDiametralInterference = ...
    shaftMinimumDiameter - hubBoreMaximumDiameter; % [mm]
maximumDiametralInterference = ...
    shaftMaximumDiameter - hubBoreMinimumDiameter; % [mm]

assert(maximumDiametralInterference >= minimumDiametralInterference, ...
    'Maksimumsoverlap er mindre end minimumsoverlap.');

fitStatus = classifyInterference( ...
    minimumDiametralInterference, maximumDiametralInterference);

minimumState = contactState(minimumDiametralInterference, a, b, ...
    shaftElasticModulus, shaftPoissonRatio, ...
    hubElasticModulus, hubPoissonRatio);

maximumState = contactState(maximumDiametralInterference, a, b, ...
    shaftElasticModulus, shaftPoissonRatio, ...
    hubElasticModulus, hubPoissonRatio);

minimumAlgebraicPressure = minimumState.algebraicPressure; % [MPa]
maximumAlgebraicPressure = maximumState.algebraicPressure; % [MPa]
minimumContactPressure = minimumState.physicalPressure;    % [MPa]
maximumContactPressure = maximumState.physicalPressure;    % [MPa]

% Automatisk kontrol mod kursusformlen ved samme materiale.
sameMaterial = abs(shaftElasticModulus-hubElasticModulus) ...
    <= 100*eps(max(shaftElasticModulus,hubElasticModulus)) && ...
    abs(shaftPoissonRatio-hubPoissonRatio) ...
    <= 100*eps(max(1,max(shaftPoissonRatio,hubPoissonRatio)));

if sameMaterial
    pMinCourse = coursePressure(minimumDiametralInterference, a, b, ...
        shaftElasticModulus, shaftPoissonRatio);
    pMaxCourse = coursePressure(maximumDiametralInterference, a, b, ...
        shaftElasticModulus, shaftPoissonRatio);

    pressureTolerance = 1e-10*max(1,max(abs([pMinCourse,pMaxCourse])));
    assert(abs(minimumAlgebraicPressure-pMinCourse) <= pressureTolerance ...
        && abs(maximumAlgebraicPressure-pMaxCourse) <= pressureTolerance, ...
        'Compliance-formen stemmer ikke med kursusformlen.');
end

%% CALCULATION - FRICTION CAPACITY
contactArea = 2*pi*a*contactLength; % [mm^2]

if isnan(frictionCoefficient)
    minimumAxialCapacity = NaN;
    maximumAxialCapacity = NaN;
    minimumTorqueCapacity = NaN;
    maximumTorqueCapacity = NaN;
    designAxialCapacity = NaN;
    designTorqueCapacity = NaN;
else
    minimumNormalForce = minimumContactPressure*contactArea; % [N]
    maximumNormalForce = maximumContactPressure*contactArea; % [N]

    minimumAxialCapacity = frictionCoefficient*minimumNormalForce; % [N]
    maximumAxialCapacity = frictionCoefficient*maximumNormalForce; % [N]
    minimumTorqueCapacity = ...
        frictionCoefficient*minimumNormalForce*a/1000; % [N*m]
    maximumTorqueCapacity = ...
        frictionCoefficient*maximumNormalForce*a/1000; % [N*m]

    designAxialCapacity = minimumAxialCapacity/capacitySafetyFactor;
    designTorqueCapacity = minimumTorqueCapacity/capacitySafetyFactor;
end

%% CALCULATION - LAME STRESSES AT MAXIMUM PRESSURE
stress = stressState(maximumContactPressure, a, b);

if isnan(hubYieldStrength) || stress.maximumHubVonMises == 0
    hubYieldSafetyFactor = NaN;
else
    hubYieldSafetyFactor = hubYieldStrength/stress.maximumHubVonMises;
end

if isnan(shaftYieldStrength) || stress.shaftVonMises == 0
    shaftYieldSafetyFactor = NaN;
else
    shaftYieldSafetyFactor = shaftYieldStrength/stress.shaftVonMises;
end

%% RESULTS
fprintf('\n============================================================\n')
fprintf('P2 - PRESPASNING\n')
fprintf('============================================================\n')
fprintf('Pasningsstatus:                    %s\n', char(fitStatus))
fprintf('Minimum diametralt overlap:        %+10.4f mm\n', ...
    minimumDiametralInterference)
fprintf('Maksimum diametralt overlap:       %+10.4f mm\n', ...
    maximumDiametralInterference)
fprintf('Algebraisk p_min:                  %+10.3f MPa\n', ...
    minimumAlgebraicPressure)
fprintf('Algebraisk p_max:                  %+10.3f MPa\n', ...
    maximumAlgebraicPressure)
fprintf('Fysisk kontakttryk, minimum:       %10.3f MPa\n', ...
    minimumContactPressure)
fprintf('Fysisk kontakttryk, maksimum:      %10.3f MPa\n', ...
    maximumContactPressure)

fprintf('\n--- DEFORMATION VED p_max ---\n')
fprintf('Navudvidelse:                      %10.6f mm\n', ...
    maximumState.physicalHubExpansion)
fprintf('Akselkontraktion:                  %10.6f mm\n', ...
    maximumState.physicalShaftContraction)
fprintf('Sum = radialt overlap Delta/2:     %10.6f mm\n', ...
    maximumState.physicalHubExpansion + ...
    maximumState.physicalShaftContraction)

fprintf('\n--- SPAENDINGER VED p_max ---\n')
fprintf('Nav: sigma_r(a):                   %+10.3f MPa\n', ...
    stress.hubRadialStressInner)
fprintf('Nav: sigma_phi(a):                 %+10.3f MPa\n', ...
    stress.hubHoopStressInner)
fprintf('Nav: sigma_phi(b):                 %+10.3f MPa\n', ...
    stress.hubHoopStressOuter)
fprintf('Nav: maks. von Mises:              %10.3f MPa\n', ...
    stress.maximumHubVonMises)
fprintf('Aksel: sigma_r = sigma_phi:        %+10.3f MPa\n', ...
    stress.shaftRadialStress)
fprintf('Aksel: von Mises:                  %10.3f MPa\n', ...
    stress.shaftVonMises)

fprintf('\n--- FRIKTIONSKAPACITET ---\n')
if isnan(frictionCoefficient)
    fprintf(['ADVARSEL: Friktionskoefficienten er NaN; ' ...
        'kapaciteten er ikke beregnet.\n'])
else
    fprintf('Aksialkapacitet, min.-maks.:       %.3f - %.3f N\n', ...
        minimumAxialCapacity, maximumAxialCapacity)
    fprintf('Momentkapacitet, min.-maks.:       %.3f - %.3f N*m\n', ...
        minimumTorqueCapacity, maximumTorqueCapacity)
    fprintf('Design aksialkapacitet:            %.3f N\n', ...
        designAxialCapacity)
    fprintf('Design momentkapacitet:            %.3f N*m\n', ...
        designTorqueCapacity)
end

pressureTable = table( ...
    ["Minimum overlap";"Maximum overlap"], ...
    [minimumDiametralInterference;maximumDiametralInterference], ...
    [minimumAlgebraicPressure;maximumAlgebraicPressure], ...
    [minimumContactPressure;maximumContactPressure], ...
    'VariableNames', {'Case','DiametralInterference_mm', ...
    'AlgebraicPressure_MPa','PhysicalPressure_MPa'});
disp(pressureTable)

results = struct;
results.fitStatus = fitStatus;
results.minimumDiametralInterference = minimumDiametralInterference;
results.maximumDiametralInterference = maximumDiametralInterference;
results.minimumAlgebraicPressure = minimumAlgebraicPressure;
results.maximumAlgebraicPressure = maximumAlgebraicPressure;
results.minimumContactPressure = minimumContactPressure;
results.maximumContactPressure = maximumContactPressure;
results.minimumAxialCapacity = minimumAxialCapacity;
results.maximumAxialCapacity = maximumAxialCapacity;
results.minimumTorqueCapacity = minimumTorqueCapacity;
results.maximumTorqueCapacity = maximumTorqueCapacity;
results.designAxialCapacity = designAxialCapacity;
results.designTorqueCapacity = designTorqueCapacity;
results.maximumHubVonMisesStress = stress.maximumHubVonMises;
results.shaftVonMisesStress = stress.shaftVonMises;
results.hubYieldSafetyFactor = hubYieldSafetyFactor;
results.shaftYieldSafetyFactor = shaftYieldSafetyFactor;
results.pressureTable = pressureTable;

%% AUTOMATIC CHECKS
fprintf('\n--- AUTOMATISKE KONTROLLER ---\n')

if minimumDiametralInterference > 0
    fprintf('OK: Der er garanteret kontakt i hele tolerancefeltet.\n')
elseif maximumDiametralInterference <= 0
    fprintf('IKKE OK: Der opbygges ikke et positivt kontakttryk.\n')
else
    fprintf(['ADVARSEL: Overgangspasning; minimum kontakttryk og ' ...
        'garanteret friktionskapacitet er nul.\n'])
end

if minimumAlgebraicPressure < 0
    fprintf(['ADVARSEL: Negativt algebraisk p_min betyder kontaktbrud; ' ...
        'det fysiske tryk saettes til nul.\n'])
end

hubStrainEstimate = maximumState.physicalHubExpansion/a;
shaftStrainEstimate = maximumState.physicalShaftContraction/ ...
    maximumState.shaftRadiusBeforeAssembly;

if max(hubStrainEstimate,shaftStrainEstimate) > smallStrainWarningLimit
    fprintf(['ADVARSEL: Relativ deformation overstiger %.4f; ' ...
        'linearelasticiteten kan vaere ugyldig.\n'], ...
        smallStrainWarningLimit)
else
    fprintf('OK: Relativ deformation er under %.4f.\n', ...
        smallStrainWarningLimit)
end

checkYield('Nav', hubYieldSafetyFactor, minimumYieldSafetyFactor)
checkYield('Aksel', shaftYieldSafetyFactor, minimumYieldSafetyFactor)

if ~isnan(requiredAxialForce)
    checkCapacity('Aksialkraft', designAxialCapacity, ...
        requiredAxialForce, 'N')
end
if ~isnan(requiredTorque)
    checkCapacity('Moment', designTorqueCapacity, ...
        requiredTorque, 'N*m')
end

%% PLOTS
if makeStressPlot && maximumContactPressure > 0
    radius = linspace(a,b,400);
    A = maximumContactPressure*a^2/(b^2-a^2);
    B = maximumContactPressure*a^2*b^2/(b^2-a^2);
    sigmaRadial = A-B./radius.^2;
    sigmaHoop = A+B./radius.^2;
    sigmaVonMises = sqrt(sigmaRadial.^2 ...
        - sigmaRadial.*sigmaHoop + sigmaHoop.^2);

    figure('Name','P2 - Navspaendinger')
    plot(radius,sigmaRadial,'LineWidth',1.5)
    hold on
    plot(radius,sigmaHoop,'LineWidth',1.5)
    plot(radius,sigmaVonMises,'--','LineWidth',1.5)
    xlabel('Radius r [mm]')
    ylabel('Spaending [MPa]')
    title('Lame-spaendinger i nav ved maksimum kontakttryk')
    legend('\sigma_r','\sigma_\phi','\sigma_{vM}','Location','best')
    grid on
    hold off
end

if makePressurePlot
    deltaSweep = linspace(min(0,minimumDiametralInterference), ...
        max(maximumDiametralInterference,eps),300);
    pressureSweep = zeros(size(deltaSweep));

    for index = 1:numel(deltaSweep)
        state = contactState(deltaSweep(index),a,b, ...
            shaftElasticModulus,shaftPoissonRatio, ...
            hubElasticModulus,hubPoissonRatio);
        pressureSweep(index) = state.physicalPressure;
    end

    figure('Name','P2 - Kontakttryk')
    plot(deltaSweep,pressureSweep,'LineWidth',1.5)
    hold on
    plot(minimumDiametralInterference,minimumContactPressure,'o')
    plot(maximumDiametralInterference,maximumContactPressure,'o')
    xline(0,':','Kontaktgraense')
    xlabel('Diametralt overlap \Delta [mm]')
    ylabel('Fysisk kontakttryk p [MPa]')
    title('Kontakttryk som funktion af overlap')
    legend('p(\Delta)','Minimum','Maksimum','Location','best')
    grid on
    hold off
end

%% PHYSICAL CONCLUSION
fprintf('\n--- FYSISK KONKLUSION ---\n')
if minimumDiametralInterference > 0
    fprintf(['Minimumstrykket bestemmer den garanterede friktionskapacitet; ' ...
        'maksimumstrykket bestemmer den kritiske spaending.\n'])
elseif maximumDiametralInterference > 0
    fprintf(['Nogle emnepar faar kontakt, andre faar spillerum. ' ...
        'Ingen positiv minimumskapacitet kan garanteres.\n'])
else
    fprintf('Geometrien giver ingen preskontakt.\n')
end
fprintf(['Konklusionen afhaenger af plane stress, fuld kontakt, ' ...
    'linearelasticitet samt de indtastede materiale- og friktionsdata.\n'])

%% OPTIONAL TEST CASES
% 1) Kursusopgave: hul 31 JS12 / aksel 35 js12.
% 2) Kursusvariant: aksel 31.1 js12, som mister sikker kontakt.
% 3) Delta = 0 og haandkontrol af friktionskapacitet.
if runOptionalTestCases
    runP2RegressionTests()
end

%% LOCAL FUNCTIONS
function state = contactState(delta,a,b,shaftE,shaftNu,hubE,hubNu)
    shaftRadius = a+delta/2;
    assert(b > a && a > 0 && shaftRadius > 0, ...
        'Kraever b > a > 0 og positiv akselradius.');

    hubCompliance = a/hubE*((a^2+b^2)/(b^2-a^2)+hubNu);
    shaftCompliance = shaftRadius/shaftE*(1-shaftNu);
    totalCompliance = hubCompliance+shaftCompliance;
    assert(totalCompliance > 0,'Samlet compliance skal vaere positiv.');

    algebraicPressure = (delta/2)/totalCompliance;
    physicalPressure = max(algebraicPressure,0);

    state.shaftRadiusBeforeAssembly = shaftRadius;
    state.algebraicPressure = algebraicPressure;
    state.physicalPressure = physicalPressure;
    state.physicalHubExpansion = physicalPressure*hubCompliance;
    state.physicalShaftContraction = physicalPressure*shaftCompliance;
end

function pressure = coursePressure(delta,a,b,E,nu)
    denominator = 4*a*b^2+delta*(b^2-a^2)*(1-nu);
    assert(abs(denominator) > eps,'Kursusformlens naevner er nul.');
    pressure = E*delta*(b^2-a^2)/denominator;
end

function status = classifyInterference(deltaMinimum,deltaMaximum)
    tolerance = 100*eps(max(1,max(abs([deltaMinimum,deltaMaximum]))));
    if deltaMinimum > tolerance
        status = "garanteret prespasning";
    elseif deltaMaximum < -tolerance
        status = "spillerum - ingen kontakt";
    elseif deltaMinimum < -tolerance && deltaMaximum > tolerance
        status = "overgangspasning";
    elseif abs(deltaMinimum) <= tolerance ...
            && abs(deltaMaximum) <= tolerance
        status = "linje-til-linje";
    else
        status = "graensetilfaelde - ingen garanteret positiv kontakt";
    end
end

function stress = stressState(pressure,a,b)
    assert(pressure >= 0,'Fysisk kontakttryk skal vaere ikke-negativt.');
    A = pressure*a^2/(b^2-a^2);
    B = pressure*a^2*b^2/(b^2-a^2);

    stress.hubRadialStressInner = A-B/a^2;
    stress.hubHoopStressInner = A+B/a^2;
    stress.hubRadialStressOuter = A-B/b^2;
    stress.hubHoopStressOuter = A+B/b^2;
    stress.maximumHubVonMises = sqrt( ...
        stress.hubRadialStressInner^2 ...
        - stress.hubRadialStressInner*stress.hubHoopStressInner ...
        + stress.hubHoopStressInner^2);

    % Massiv aksel under udvendigt tryk; sigma_z = 0.
    stress.shaftRadialStress = -pressure;
    stress.shaftHoopStress = -pressure;
    stress.shaftVonMises = pressure;
end

function checkYield(component,safetyFactor,requiredSafety)
    if isnan(safetyFactor)
        fprintf(['ADVARSEL: %ss flydespaending er ikke oplyst; ' ...
            'flydning er ikke kontrolleret.\n'],component)
    elseif safetyFactor >= requiredSafety
        fprintf('OK: %ss sikkerhed mod flydning er %.3f.\n', ...
            component,safetyFactor)
    else
        fprintf('IKKE OK: %ss sikkerhed mod flydning er %.3f.\n', ...
            component,safetyFactor)
    end
end

function checkCapacity(quantity,capacity,required,unit)
    if isnan(capacity)
        fprintf('ADVARSEL: %s kan ikke kontrolleres uden friktion.\n',quantity)
    elseif capacity >= required
        fprintf('OK: %s-kapacitet %.3f %s >= krav %.3f %s.\n', ...
            quantity,capacity,unit,required,unit)
    else
        fprintf('IKKE OK: %s-kapacitet %.3f %s < krav %.3f %s.\n', ...
            quantity,capacity,unit,required,unit)
    end
end

function runP2RegressionTests()
    fprintf('\n============================================================\n')
    fprintf('OPTIONAL TEST CASES - P2\n')
    fprintf('============================================================\n')

    a = 15.5; b = 25.5; E = 200000; nu = 0.30;

    % Test 1: kursusopgaven.
    pMin = contactState(3.75,a,b,E,nu,E,nu);
    pMax = contactState(4.25,a,b,E,nu,E,nu);
    assertClose(pMin.algebraicPressure,7429.016651869032, ...
        'Kursusopgave p_min')
    assertClose(pMax.algebraicPressure,8390.463521948224, ...
        'Kursusopgave p_max')
    fprintf('OK: Kursusformlen giver p_min = %.3f og p_max = %.3f MPa.\n', ...
        pMin.algebraicPressure,pMax.algebraicPressure)
    fprintf(['ADVARSEL: Kursussliden skriver 7627 og 8644 MPa; ' ...
        'de tal stemmer ikke med slidens viste formel og input.\n'])

    % Test 2: aksel 31.1 js12.
    transitionMin = contactState(-0.15,a,b,E,nu,E,nu);
    transitionMax = contactState(0.35,a,b,E,nu,E,nu);
    assertClose(transitionMin.algebraicPressure,-305.41971000026075, ...
        'Kursusvariant p_min')
    assertClose(transitionMax.algebraicPressure,710.1156845255401, ...
        'Kursusvariant p_max')
    assert(transitionMin.physicalPressure == 0, ...
        'Negativt algebraisk tryk skal give fysisk p = 0.');
    assert(strcmp(classifyInterference(-0.15,0.35),"overgangspasning"), ...
        'Kursusvarianten skal vaere en overgangspasning.');
    fprintf('OK: Kursusvarianten giver p_min = %.3f og p_max = %.3f MPa.\n', ...
        transitionMin.algebraicPressure,transitionMax.algebraicPressure)

    % Test 3: Delta = 0 og kapacitetskontrol.
    zeroState = contactState(0,10,20,E,nu,E,nu);
    assert(zeroState.physicalPressure == 0,'Delta = 0 skal give p = 0.');

    normalForce = 100*2*pi*10*20;  % p=100 MPa, a=10 mm, L=20 mm
    assertClose(0.10*normalForce,4000*pi,'Aksialkapacitet')
    assertClose(0.10*normalForce*10/1000,40*pi,'Momentkapacitet')

    fprintf('OK: Randtilfaelde og friktionskapacitet bestod.\n')
    fprintf('Alle P2-regressionstest bestod.\n')
end

function assertClose(actual,expected,label)
    tolerance = 1e-12*max(1,abs(expected));
    assert(abs(actual-expected) <= tolerance, ...
        sprintf('%s fejlede: actual=%.15g, expected=%.15g.', ...
        label,actual,expected));
end
