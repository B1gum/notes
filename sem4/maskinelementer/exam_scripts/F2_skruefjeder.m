%% F2 - CYLINDRISK SKRUEFJEDER: STIVHED, DEFORMATION OG SPAENDING
% Brug dette script naar:
%   - en cylindrisk trykskruefjeder har rund traad;
%   - traaddiameter d, middeldiameter D, aktive vindinger Na og G er kendt;
%   - fjederkonstant, deformation og forskydningsspaending skal bestemmes.
%
% Brug ikke dette script naar:
%   - fjederen skal dimensioneres ved soegning efter d, D og Na (brug F3);
%   - fjederen er konisk, tallerkenformet, ikke-lineaer eller har firkantet traad;
%   - udmattelse, knaekning eller dynamiske svingninger er opgavens hovedemne.
%
% Skal bestemmes manuelt foerst:
%   - om D er MIDDELDIAMETEREN og d er traaddiameteren;
%   - antal aktive vindinger Na;
%   - forskydningsmodul G fra opgaven/materialedata;
%   - eventuel tilladelig forskydningsspaending;
%   - totalt antal vindinger Nt fra endetype/tegning, hvis bloklaengde kontrolleres.
%
% Kursusmetode:
%   C     = D/d
%   K_B   = (4*C + 2)/(4*C - 3)          Bergstrasser-faktor
%   k     = d^4*G/(8*D^3*Na)
%   delta = F/k
%   tau   = K_B*8*F*D/(pi*d^3)
%
% Enheder: N, mm, N/mm og MPa (= N/mm^2).
% Ingen ekstra MATLAB-toolboxes er noedvendige.

clearvars
clc
close all

%% ASSUMPTIONS AND MANUAL INPUT
% - Fjederen er lineart elastisk og belastet aksialt i tryk.
% - Traaden er rund, og D er fjederens middeldiameter.
% - Spaendingen beregnes med Bergstrasser-faktoren fra kursusmaterialet.
% - Friktions-, dynamik-, knaeknings- og udmattelseseffekter er ikke medtaget.
% - Endetypen bruges kun som dokumentation. Nt skal indtastes manuelt,
%   fordi relationen mellem endetype, Na og Nt ikke fremgaar entydigt af
%   det anvendte kursusmateriale.

%% INPUT
wireDiameter = 2.25;               % [mm] d, traaddiameter
meanCoilDiameter = 11.7;           % [mm] D, middeldiameter
activeCoils = 21;                  % [-] Na, antal aktive vindinger
shearModulus = 81e3;               % [MPa] G, 81 GPa = 81000 MPa
springLoads = [25, 156];           % [N] F_i, undersoegte aksiale trykkraefter

freeLength = 98;                   % [mm] L0, fri laengde; NaN hvis ukendt
endType = "ikke specificeret";     % [-] Dokumentation af fjederender
totalCoils = NaN;                  % [-] Nt inkl. inaktive vindinger; manuelt opslag
minimumClashAllowance = 0;         % [mm] Kraevet reserve foer bloklaengde

allowableShearStress = NaN;        % [MPa] Tilladelig tau; NaN hvis ikke oplyst
makePlots = true;                  % [-] Vis kraft/deformation og spaending/last
runTests = true;                   % [-] Koer kursus-, haand- og fejltest
testRelativeTolerance = 1e-9;      % [-] Relativ tolerans for automatiske tests

%% UNIT CHECK AND VALIDATION
assert(isscalar(wireDiameter) && isfinite(wireDiameter) && ...
    wireDiameter > 0, ...
    'wireDiameter skal vaere en positiv skalar [mm].')

assert(isscalar(meanCoilDiameter) && isfinite(meanCoilDiameter) && ...
    meanCoilDiameter > wireDiameter, ...
    'meanCoilDiameter skal vaere stoerre end wireDiameter [mm].')

assert(isscalar(activeCoils) && isfinite(activeCoils) && ...
    activeCoils > 0, ...
    'activeCoils skal vaere positiv.')

assert(isscalar(shearModulus) && isfinite(shearModulus) && ...
    shearModulus > 0, ...
    'shearModulus skal vaere positiv [MPa].')

assert(isnumeric(springLoads) && isvector(springLoads) && ...
    ~isempty(springLoads) && all(isfinite(springLoads)) && ...
    all(springLoads >= 0), ...
    'springLoads skal vaere en ikke-tom vektor af ikke-negative kraefter [N].')

assert((isscalar(freeLength) && isnan(freeLength)) || ...
    (isscalar(freeLength) && isfinite(freeLength) && freeLength > 0), ...
    'freeLength skal vaere positiv [mm] eller NaN.')

assert((isscalar(totalCoils) && isnan(totalCoils)) || ...
    (isscalar(totalCoils) && isfinite(totalCoils) && ...
    totalCoils >= activeCoils), ...
    'totalCoils skal vaere NaN eller mindst lig activeCoils.')

assert(isscalar(minimumClashAllowance) && ...
    isfinite(minimumClashAllowance) && minimumClashAllowance >= 0, ...
    'minimumClashAllowance skal vaere ikke-negativ [mm].')

assert((isscalar(allowableShearStress) && isnan(allowableShearStress)) || ...
    (isscalar(allowableShearStress) && ...
    isfinite(allowableShearStress) && allowableShearStress > 0), ...
    'allowableShearStress skal vaere positiv [MPa] eller NaN.')

assert(islogical(makePlots) && isscalar(makePlots), ...
    'makePlots skal vaere true eller false.')

assert(islogical(runTests) && isscalar(runTests), ...
    'runTests skal vaere true eller false.')

assert(isscalar(testRelativeTolerance) && ...
    isfinite(testRelativeTolerance) && testRelativeTolerance > 0, ...
    'testRelativeTolerance skal vaere positiv.')

%% CALCULATION
results = calculateHelicalCompressionSpring( ...
    wireDiameter, meanCoilDiameter, activeCoils, shearModulus, ...
    springLoads, freeLength, totalCoils, minimumClashAllowance, ...
    allowableShearStress);

%% RESULTS
fprintf('\n================ F2 RESULTATER ================\n')
fprintf('Endetype                         : %s\n', endType)
fprintf('Traaddiameter d                  : %.6g mm\n', wireDiameter)
fprintf('Middeldiameter D                 : %.6g mm\n', meanCoilDiameter)
fprintf('Indvendig diameter D_i           : %.6g mm\n', results.insideDiameter)
fprintf('Udvendig diameter D_o            : %.6g mm\n', results.outsideDiameter)
fprintf('Aktive vindinger N_a             : %.6g\n', activeCoils)
fprintf('Vindingsforhold C = D/d          : %.6g\n', results.springIndex)
fprintf('Bergstrasser-faktor K_B          : %.6g\n', ...
    results.bergstrasserFactor)
fprintf('Fjederkonstant k                 : %.6g N/mm\n', ...
    results.springStiffness)

resultTable = table( ...
    results.force(:), ...
    results.deflection(:), ...
    results.nominalTorsionalShearStress(:), ...
    results.correctedShearStress(:), ...
    results.springEnergy(:), ...
    results.loadedLength(:), ...
    'VariableNames', {'F_N','delta_mm','tau_nom_MPa', ...
    'tau_Bergstrasser_MPa','energi_Nmm','belastet_laengde_mm'});

disp(resultTable)

if results.solidGeometryAvailable
    fprintf('Bloklaengde L_s = N_t*d          : %.6g mm\n', ...
        results.solidLength)
    fprintf('Maks. geometrisk vandring        : %.6g mm\n', ...
        results.availableDeflectionToSolid)
    fprintf('Mindste restafstand til blok     : %.6g mm\n', ...
        min(results.clearanceToSolid))
else
    fprintf(['Bloklaengde er ikke beregnet: Angiv totalCoils fra ' ...
        'endetype/tegning.\n'])
end

if results.allowableStressAvailable
    stressTable = table(results.force(:), ...
        results.correctedShearStress(:), ...
        results.safetyFactorShear(:), ...
        'VariableNames', {'F_N','tau_MPa','sikkerhedsfaktor'});
    disp(stressTable)
end

%% AUTOMATIC CHECKS
if results.springIndexWithinRecommendedRange
    fprintf('OK: Vindingsforholdet er inden for kursusintervallet 4 <= C <= 12.\n')
else
    fprintf(['ADVARSEL: C = %.4g ligger uden for kursusintervallet ' ...
        '4 <= C <= 12.\n'], results.springIndex)
end

if results.activeCoilsWithinShigleyRange
    fprintf('OK: Antal aktive vindinger er inden for 3 <= N_a <= 15.\n')
else
    fprintf(['ADVARSEL: N_a = %.4g ligger uden for Shigley-anbefalingen ' ...
        '3 <= N_a <= 15. Kursusnoterne bemaerker, at intervallet ikke ' ...
        'angives i DS/EN 13906.\n'], activeCoils)
end

if results.freeLengthAvailable
    if results.loadedLengthPositive
        fprintf('OK: Den beregnede belastede laengde er positiv for alle laster.\n')
    else
        fprintf(['IKKE OK: Mindst en deformation er stoerre end eller lig ' ...
            'den frie laengde.\n'])
    end
else
    fprintf('ADVARSEL: Fri laengde er ikke angivet; belastet laengde kontrolleres ikke.\n')
end

if results.solidGeometryAvailable
    if results.solidClearanceOK
        fprintf(['OK: Fjederen naar ikke bloklaengden, inklusive den kraevede ' ...
            'reserve.\n'])
    else
        fprintf(['IKKE OK: Fjederen naar eller overskrider bloklaengden for ' ...
            'mindst en last.\n'])
    end
else
    fprintf(['ADVARSEL: Bloklaengdekontrol er ikke udført, fordi totalCoils ' ...
        'ikke er angivet.\n'])
end

if results.allowableStressAvailable
    if results.allowableStressOK
        fprintf('OK: Alle beregnede spaendinger er under den tilladelige spaending.\n')
    else
        fprintf(['IKKE OK: Mindst en beregnet forskydningsspaending overskrider ' ...
            'den tilladelige spaending.\n'])
    end
else
    fprintf(['ADVARSEL: Ingen tilladelig forskydningsspaending er angivet; ' ...
        'styrken kan ikke godkendes.\n'])
end

%% PLOTS
if makePlots
    maximumPlotLoad = max(springLoads);

    if maximumPlotLoad == 0
        maximumPlotLoad = 1;
    end

    plotLoads = linspace(0, 1.05*maximumPlotLoad, 200);
    plotDeflections = plotLoads/results.springStiffness;

    figure('Name','F2 - kraft og deformation')
    plot(plotDeflections, plotLoads, 'LineWidth', 1.5)
    hold on
    scatter(results.deflection, results.force, 45, 'filled')
    hold off
    xlabel('Deformation \delta [mm]')
    ylabel('Kraft F [N]')
    title('Lineær fjederkarakteristik')
    legend('F = k\delta','Lasttilfaelde','Location','best')
    grid on

    plotStresses = results.bergstrasserFactor .* ...
        (8*plotLoads*meanCoilDiameter)/(pi*wireDiameter^3);

    figure('Name','F2 - forskydningsspaending')
    plot(plotLoads, plotStresses, 'LineWidth', 1.5)
    hold on
    scatter(results.force, results.correctedShearStress, 45, 'filled')

    if results.allowableStressAvailable
        yline(allowableShearStress, '--', ...
            'Tilladelig \tau', 'LabelHorizontalAlignment','left')
    end

    hold off
    xlabel('Kraft F [N]')
    ylabel('Korrigeret forskydningsspaending \tau [MPa]')
    title('Bergstrasser-korrigeret fjedertraadsspaending')
    legendEntries = ["Beregnet sammenhaeng","Lasttilfaelde"];

    if results.allowableStressAvailable
        legendEntries(end+1) = "Tilladelig spaending";
    end

    legend(legendEntries, 'Location','best')
    grid on
end

%% PHYSICAL CONCLUSION
[maxStress, criticalIndex] = max(results.correctedShearStress);
fprintf('\n================ FYSISK KONKLUSION ================\n')
fprintf(['Fjederens stivhed er %.4g N/mm. Ved den stoerste undersoegte ' ...
    'last, F = %.4g N, bliver deformationen %.4g mm og den ' ...
    'Bergstrasser-korrigerede spaending %.4g MPa.\n'], ...
    results.springStiffness, results.force(criticalIndex), ...
    results.deflection(criticalIndex), maxStress)

if ~results.allowableStressAvailable
    fprintf(['En endelig styrkegodkendelse kraever en tilladelig ' ...
        'forskydningsspaending fra opgaven eller materialedata.\n'])
end

if ~results.solidGeometryAvailable
    fprintf(['Kontrol mod bloklaengde kraever totalt antal vindinger N_t, ' ...
        'som skal bestemmes ud fra endetype eller tegning.\n'])
end

%% OPTIONAL TEST CASES
% 1) Kursusopgave 2.1.
% 2) Simpel haandkontrol med k = 16 N/mm og delta = 1 mm.
% 3) Fejltilfaelde, hvor fjederen presses forbi bloklaengden.
if runTests
    testReport = runF2Tests(testRelativeTolerance);
    disp(testReport)

    assert(all(testReport.Bestaaet), ...
        'Mindst en F2-test fejlede. Se testReport.')

    fprintf('OK: Alle F2-kursus-, haand- og fejltests bestaar.\n')
end

%% LOCAL FUNCTIONS
function out = calculateHelicalCompressionSpring( ...
        d, D, Na, G, force, L0, Nt, clashAllowance, tauAllow)

    force = force(:).';

    assert(isfinite(d) && isscalar(d) && d > 0, ...
        'd skal vaere positiv [mm].')
    assert(isfinite(D) && isscalar(D) && D > d, ...
        'D skal vaere stoerre end d [mm].')
    assert(isfinite(Na) && isscalar(Na) && Na > 0, ...
        'Na skal vaere positiv.')
    assert(isfinite(G) && isscalar(G) && G > 0, ...
        'G skal vaere positiv [MPa].')
    assert(all(isfinite(force)) && all(force >= 0), ...
        'Kraefter skal vaere ikke-negative [N].')

    C = D/d;
    KB = (4*C + 2)/(4*C - 3);
    k = d^4*G/(8*D^3*Na);

    delta = force/k;
    tauNominal = 8*force*D/(pi*d^3);
    tauCorrected = KB*tauNominal;
    energy = 0.5*force.*delta;

    freeLengthAvailable = isscalar(L0) && isfinite(L0);
    solidGeometryAvailable = freeLengthAvailable && ...
        isscalar(Nt) && isfinite(Nt);

    if freeLengthAvailable
        loadedLength = L0-delta;
        loadedLengthPositive = all(loadedLength > 0);
    else
        loadedLength = NaN(size(delta));
        loadedLengthPositive = false;
    end

    if solidGeometryAvailable
        solidLength = Nt*d;
        availableDeflection = L0-solidLength;
        clearanceToSolid = availableDeflection-delta;
        solidClearanceOK = availableDeflection >= 0 && ...
            all(clearanceToSolid >= clashAllowance);
    else
        solidLength = NaN;
        availableDeflection = NaN;
        clearanceToSolid = NaN(size(delta));
        solidClearanceOK = false;
    end

    allowableStressAvailable = isscalar(tauAllow) && isfinite(tauAllow);

    if allowableStressAvailable
        safetyFactor = tauAllow./tauCorrected;
        safetyFactor(tauCorrected == 0) = Inf;
        allowableStressOK = all(tauCorrected <= tauAllow);
    else
        safetyFactor = NaN(size(tauCorrected));
        allowableStressOK = false;
    end

    out.force = force;
    out.springIndex = C;
    out.bergstrasserFactor = KB;
    out.springStiffness = k;
    out.deflection = delta;
    out.nominalTorsionalShearStress = tauNominal;
    out.correctedShearStress = tauCorrected;
    out.springEnergy = energy;
    out.insideDiameter = D-d;
    out.outsideDiameter = D+d;

    out.springIndexWithinRecommendedRange = C >= 4 && C <= 12;
    out.activeCoilsWithinShigleyRange = Na >= 3 && Na <= 15;

    out.freeLengthAvailable = freeLengthAvailable;
    out.loadedLength = loadedLength;
    out.loadedLengthPositive = loadedLengthPositive;

    out.solidGeometryAvailable = solidGeometryAvailable;
    out.solidLength = solidLength;
    out.availableDeflectionToSolid = availableDeflection;
    out.clearanceToSolid = clearanceToSolid;
    out.solidClearanceOK = solidClearanceOK;

    out.allowableStressAvailable = allowableStressAvailable;
    out.safetyFactorShear = safetyFactor;
    out.allowableStressOK = allowableStressOK;
end

function report = runF2Tests(relativeTolerance)
    testNames = [ ...
        "Kursusopgave 2.1"; ...
        "Simpel haandkontrol"; ...
        "Fejltilfaelde: bloklaengde"];

    calculated = strings(3,1);
    maximumRelativeError = zeros(3,1);
    passed = false(3,1);

    % -------------------------------------------------------------
    % Kursusopgave 2.1
    % d=2.25 mm, D=11.7 mm, Na=21, G=81 GPa
    % F1=25 N og F2=156 N
    % -------------------------------------------------------------
    r = calculateHelicalCompressionSpring( ...
        2.25, 11.7, 21, 81e3, [25,156], 98, NaN, 0, NaN);

    expected = [ ...
        5.2, ...
        1.280898876404494, ...
        7.715218398465441, ...
        3.240348971193415, ...
        20.21977758024691, ...
        83.75934549801686, ...
        522.6583159076253];

    actual = [ ...
        r.springIndex, ...
        r.bergstrasserFactor, ...
        r.springStiffness, ...
        r.deflection, ...
        r.correctedShearStress];

    maximumRelativeError(1) = maximumRelativeDifference(actual, expected);
    passed(1) = maximumRelativeError(1) <= relativeTolerance;

    calculated(1) = sprintf( ...
        'k=%.6f N/mm, delta=[%.5f %.5f] mm, tau=[%.5f %.5f] MPa', ...
        r.springStiffness, r.deflection(1), r.deflection(2), ...
        r.correctedShearStress(1), r.correctedShearStress(2));

    % -------------------------------------------------------------
    % Simpel haandkontrol
    % d=2 mm, D=10 mm, Na=10, G=80000 MPa giver k=16 N/mm.
    % F=16 N giver derfor delta=1 mm.
    % -------------------------------------------------------------
    r = calculateHelicalCompressionSpring( ...
        2, 10, 10, 80e3, 16, NaN, NaN, 0, NaN);

    expectedK = 16;
    expectedDelta = 1;
    expectedC = 5;

    actual = [r.springStiffness, r.deflection, r.springIndex];
    expected = [expectedK, expectedDelta, expectedC];

    maximumRelativeError(2) = maximumRelativeDifference(actual, expected);
    passed(2) = maximumRelativeError(2) <= relativeTolerance;

    calculated(2) = sprintf( ...
        'k=%.6f N/mm, delta=%.6f mm, C=%.6f', ...
        r.springStiffness, r.deflection, r.springIndex);

    % -------------------------------------------------------------
    % Fejltilfaelde
    % L0=20 mm, Nt=8 og d=2 mm giver Ls=16 mm og 4 mm vandring.
    % F=120 N giver delta=4.5 mm, saa bloklaengden overskrides.
    % -------------------------------------------------------------
    r = calculateHelicalCompressionSpring( ...
        2, 10, 6, 80e3, 120, 20, 8, 0, NaN);

    expectedDelta = 4.5;
    expectedSolidLength = 16;
    expectedClearance = -0.5;

    actual = [r.deflection, r.solidLength, r.clearanceToSolid];
    expected = [expectedDelta, expectedSolidLength, expectedClearance];

    numericalOK = maximumRelativeDifference(actual, expected) <= ...
        relativeTolerance;
    logicalOK = r.solidGeometryAvailable && ~r.solidClearanceOK;

    maximumRelativeError(3) = maximumRelativeDifference(actual, expected);
    passed(3) = numericalOK && logicalOK;

    calculated(3) = sprintf( ...
        'delta=%.6f mm, Ls=%.6f mm, restafstand=%.6f mm', ...
        r.deflection, r.solidLength, r.clearanceToSolid);

    report = table(testNames, calculated, maximumRelativeError, passed, ...
        'VariableNames', ...
        {'Test','Beregnet','MaksRelativFejl','Bestaaet'});
end

function value = maximumRelativeDifference(actual, expected)
    scale = max(1, abs(expected));
    value = max(abs(actual-expected)./scale);
end
