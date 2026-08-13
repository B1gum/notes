%% P1 - ISO-TOLERANCER, GRAENSEMAAL OG PASNINGER
% Brug dette script naar:
%   Opgaven giver hullets og akslens nominelle maal samt oe/re afvigelser
%   fra et ISO-tabelopslag, og der spoerges efter graensemaal, spillerum,
%   overlap eller pasningstype.
%
% Brug ikke dette script naar:
%   Kontakttryk, overfoerbart moment eller spaendinger i en prespasning
%   skal beregnes. Brug da et P2-script efter P1.
%
% Skal bestemmes manuelt foerst:
%   1) Korrekt tolerancebetegnelse for hul og aksel.
%   2) Oevre og nedre afvigelse fra kursustabel/ISO-opslag.
%   3) Om opgaven kraever spillerums-, overgangs- eller prespasning.

clear
clc
close all

%% ASSUMPTIONS AND MANUAL INPUT
% Enhedssystem:
%   Diameter og graensemaal: [mm]
%   Tabelafvigelser: [micrometer]
%
% Fortegnskonvention:
%   Positiv afvigelse ligger over det nominelle maal.
%   Negativ afvigelse ligger under det nominelle maal.
%
% Worst-case-metode:
%   Alle kombinationer af graensemaal antages mulige.
%   Der anvendes ikke statistisk toleranceregning.
%
% Notation:
%   ES, EI: hullets oevre og nedre afvigelse.
%   es, ei: akslens oevre og nedre afvigelse.
%   S_min = D_hul,min - d_aksel,max
%   S_max = D_hul,max - d_aksel,min
%   Negativt S betyder overlap (interference).

%% INPUT
holeNominalDiameter = 31;        % [mm] Hullets nominelle diameter
shaftNominalDiameter = 35;       % [mm] Akslens nominelle diameter

holeUpperDeviation = +125;       % [micrometer] ES, hullets oevre afvigelse
holeLowerDeviation = -125;       % [micrometer] EI, hullets nedre afvigelse
shaftUpperDeviation = +125;      % [micrometer] es, akslens oevre afvigelse
shaftLowerDeviation = -125;      % [micrometer] ei, akslens nedre afvigelse

holeToleranceLabel = "JS12";     % [-] Kun dokumentation; bruges ikke til opslag
shaftToleranceLabel = "js12";    % [-] Kun dokumentation; bruges ikke til opslag

requiredFitType = "prespasning"; % [-] "spillerumspasning", "overgangspasning",
                                 %     "prespasning" eller "ingen"

runOptionalTestCases = true;     % [-] true koerer regressionstestene nederst
makeTolerancePlot = true;        % [-] true viser tolerancezonerne grafisk

%% UNIT CHECK AND VALIDATION
inputValues = [holeNominalDiameter, shaftNominalDiameter, ...
    holeUpperDeviation, holeLowerDeviation, ...
    shaftUpperDeviation, shaftLowerDeviation];

assert(all(isfinite(inputValues)), ...
    'Alle numeriske input skal vaere endelige tal.');
assert(isscalar(holeNominalDiameter) && holeNominalDiameter > 0, ...
    'Hullets nominelle diameter skal vaere en positiv skalar.');
assert(isscalar(shaftNominalDiameter) && shaftNominalDiameter > 0, ...
    'Akslens nominelle diameter skal vaere en positiv skalar.');
assert(holeUpperDeviation >= holeLowerDeviation, ...
    'For hullet skal ES vaere stoerre end eller lig EI.');
assert(shaftUpperDeviation >= shaftLowerDeviation, ...
    'For akslen skal es vaere stoerre end eller lig ei.');

validRequiredFitTypes = ["spillerumspasning", "overgangspasning", ...
    "prespasning", "ingen"];
assert(any(strcmpi(requiredFitType, validRequiredFitTypes)), ...
    'requiredFitType har en ugyldig vaerdi.');

if abs(holeNominalDiameter - shaftNominalDiameter) > 1e-12
    warning('P1:DifferentNominalDiameters', ...
        ['Hul og aksel har forskellige nominelle diametre. ' ...
         'Beregningen er gyldig, men kontrollér at tegningen er aflæst korrekt.']);
end

%% CALCULATION
% Omregning: 1 micrometer = 0.001 mm.
micrometerToMillimeter = 1e-3; % [mm/micrometer]

fit = calculateP1Fit( ...
    holeNominalDiameter, shaftNominalDiameter, ...
    holeUpperDeviation * micrometerToMillimeter, ...
    holeLowerDeviation * micrometerToMillimeter, ...
    shaftUpperDeviation * micrometerToMillimeter, ...
    shaftLowerDeviation * micrometerToMillimeter);

holeMinimumDiameter = fit.holeMinimumDiameter;
holeMaximumDiameter = fit.holeMaximumDiameter;
shaftMinimumDiameter = fit.shaftMinimumDiameter;
shaftMaximumDiameter = fit.shaftMaximumDiameter;

holeToleranceWidth = fit.holeToleranceWidth;
shaftToleranceWidth = fit.shaftToleranceWidth;
fitToleranceWidth = fit.fitToleranceWidth;

minimumSignedClearance = fit.minimumSignedClearance;
maximumSignedClearance = fit.maximumSignedClearance;

minimumClearance = fit.minimumClearance;
maximumClearance = fit.maximumClearance;
minimumInterference = fit.minimumInterference;
maximumInterference = fit.maximumInterference;
fitClassification = fit.classification;

%% RESULTS
fprintf('\n============================================================\n')
fprintf('P1 - ISO-TOLERANCER OG PASNINGER\n')
fprintf('============================================================\n')
fprintf('Hul:   %.3f mm %s\n', holeNominalDiameter, char(holeToleranceLabel))
fprintf('Aksel: %.3f mm %s\n', shaftNominalDiameter, char(shaftToleranceLabel))

fprintf('\n--- TABELAFVIGELSER ---\n')
fprintf('Hul:   EI = %+8.1f micrometer, ES = %+8.1f micrometer\n', ...
    holeLowerDeviation, holeUpperDeviation)
fprintf('Aksel: ei = %+8.1f micrometer, es = %+8.1f micrometer\n', ...
    shaftLowerDeviation, shaftUpperDeviation)

fprintf('\n--- GRAENSEMAAL ---\n')
fprintf('Huldiameter:   %.3f mm <= D_hul <= %.3f mm\n', ...
    holeMinimumDiameter, holeMaximumDiameter)
fprintf('Akseldiameter: %.3f mm <= d_aksel <= %.3f mm\n', ...
    shaftMinimumDiameter, shaftMaximumDiameter)

fprintf('\n--- TOLERANCEBREDDER ---\n')
fprintf('Hultolerance:       %.3f mm\n', holeToleranceWidth)
fprintf('Akseltolerance:     %.3f mm\n', shaftToleranceWidth)
fprintf('Samlet pasningstol: %.3f mm\n', fitToleranceWidth)

fprintf('\n--- SPILLERUM / OVERLAP ---\n')
fprintf('S_min = D_hul,min - d_aksel,max = %+8.3f mm\n', ...
    minimumSignedClearance)
fprintf('S_max = D_hul,max - d_aksel,min = %+8.3f mm\n', ...
    maximumSignedClearance)
fprintf('Maksimalt spillerum: %.3f mm\n', maximumClearance)
fprintf('Minimalt spillerum:  %.3f mm\n', minimumClearance)
fprintf('Minimalt overlap:    %.3f mm\n', minimumInterference)
fprintf('Maksimalt overlap:   %.3f mm\n', maximumInterference)

fprintf('\nPasningsklassifikation: %s\n', char(fitClassification))

results = struct;
results.holeMinimumDiameter = holeMinimumDiameter;           % [mm]
results.holeMaximumDiameter = holeMaximumDiameter;           % [mm]
results.shaftMinimumDiameter = shaftMinimumDiameter;         % [mm]
results.shaftMaximumDiameter = shaftMaximumDiameter;         % [mm]
results.minimumSignedClearance = minimumSignedClearance;     % [mm]
results.maximumSignedClearance = maximumSignedClearance;     % [mm]
results.minimumClearance = minimumClearance;                 % [mm]
results.maximumClearance = maximumClearance;                 % [mm]
results.minimumInterference = minimumInterference;           % [mm]
results.maximumInterference = maximumInterference;           % [mm]
results.fitToleranceWidth = fitToleranceWidth;               % [mm]
results.fitClassification = fitClassification;               % [-]

%% AUTOMATIC CHECKS
calculatedFitWidth = maximumSignedClearance - minimumSignedClearance;
widthCheckTolerance = 100 * eps(max(1, abs(fitToleranceWidth)));

assert(abs(calculatedFitWidth - fitToleranceWidth) <= widthCheckTolerance, ...
    'Intern kontrol fejlede: pasningstolerancen stemmer ikke.');

if strcmpi(requiredFitType, "ingen")
    fprintf('\nADVARSEL: Der er ikke angivet en kraevet pasningstype.\n')
elseif strcmpi(requiredFitType, fitClassification)
    fprintf('\nOK: Den beregnede pasning er en %s som kraevet.\n', ...
        char(fitClassification))
else
    fprintf('\nIKKE OK: Kraevet type er %s, men beregnet type er %s.\n', ...
        char(requiredFitType), char(fitClassification))
end

switch fitClassification
    case "spillerumspasning"
        fprintf('OK: Der er altid spillerum mellem hul og aksel.\n')
    case "prespasning"
        fprintf('OK: Der er altid overlap mellem hul og aksel.\n')
    case "overgangspasning"
        fprintf(['ADVARSEL: Samlingen kan faa enten spillerum eller overlap. ' ...
            'Kontakt er derfor ikke garanteret.\n'])
    case "linje-til-linje"
        fprintf(['ADVARSEL: Graensemaalene giver kun linje-til-linje kontakt. ' ...
            'Der er ingen sikker reserve.\n'])
end

%% PLOTS
if makeTolerancePlot
    figure('Name', 'P1 - Tolerancezoner')
    hold on

    plot([1 1], [holeMinimumDiameter holeMaximumDiameter], ...
        '-', 'LineWidth', 10)
    plot([2 2], [shaftMinimumDiameter shaftMaximumDiameter], ...
        '-', 'LineWidth', 10)

    plot(1, holeNominalDiameter, 'kx', 'MarkerSize', 10, 'LineWidth', 1.5)
    plot(2, shaftNominalDiameter, 'kx', 'MarkerSize', 10, 'LineWidth', 1.5)

    plot([0.85 1.15], [holeMinimumDiameter holeMinimumDiameter], 'k-')
    plot([0.85 1.15], [holeMaximumDiameter holeMaximumDiameter], 'k-')
    plot([1.85 2.15], [shaftMinimumDiameter shaftMinimumDiameter], 'k-')
    plot([1.85 2.15], [shaftMaximumDiameter shaftMaximumDiameter], 'k-')

    xlim([0.5 2.5])
    xticks([1 2])
    xticklabels({'Hul', 'Aksel'})
    ylabel('Diameter [mm]')
    title(sprintf('Tolerancezoner - %s', char(fitClassification)))
    grid on
    box on
    hold off
end

%% PHYSICAL CONCLUSION
fprintf('\n--- FYSISK KONKLUSION ---\n')
switch fitClassification
    case "spillerumspasning"
        fprintf(['Selv ved vaerste kombination er hullet stoerre end akslen. ' ...
            'Samlingen kan monteres med spillerum.\n'])
    case "prespasning"
        fprintf(['Selv ved vaerste kombination er akslen stoerre end hullet. ' ...
            'Der er garanteret overlap; kontakttryk behandles i P2.\n'])
    case "overgangspasning"
        fprintf(['Tolerancezonerne overlapper. Nogle emnepar faar spillerum, ' ...
            'andre faar overlap; preskontakt er ikke garanteret.\n'])
    case "linje-til-linje"
        fprintf(['Graensekombinationen giver hverken sikkert spillerum eller ' ...
            'sikkert overlap.\n'])
end
fprintf(['Konklusionen afhaenger direkte af de manuelt opslagne ES, EI, es og ei. ' ...
    'Kontrollér derfor altid diameterinterval og tabelkolonne.\n'])

%% OPTIONAL TEST CASES
% Test 1 og 2 er baseret paa kursets interference-fit-opgave.
% Test 3 er en simpel haandkontrol.
% Test 4 er et randtilfaelde.
if runOptionalTestCases
    runP1RegressionTests()
end

%% LOCAL FUNCTIONS
function fit = calculateP1Fit(holeNominal, shaftNominal, ...
    holeUpper_mm, holeLower_mm, shaftUpper_mm, shaftLower_mm)

    assert(holeUpper_mm >= holeLower_mm, ...
        'Hullets oevre afvigelse skal vaere >= den nedre.');
    assert(shaftUpper_mm >= shaftLower_mm, ...
        'Akslens oevre afvigelse skal vaere >= den nedre.');

    % Graensemaal.
    fit.holeMinimumDiameter = holeNominal + holeLower_mm;
    fit.holeMaximumDiameter = holeNominal + holeUpper_mm;
    fit.shaftMinimumDiameter = shaftNominal + shaftLower_mm;
    fit.shaftMaximumDiameter = shaftNominal + shaftUpper_mm;

    assert(fit.holeMinimumDiameter > 0 && fit.shaftMinimumDiameter > 0, ...
        'De beregnede minimumsdiametre skal vaere positive.');

    % Tolerancebredder.
    fit.holeToleranceWidth = ...
        fit.holeMaximumDiameter - fit.holeMinimumDiameter;
    fit.shaftToleranceWidth = ...
        fit.shaftMaximumDiameter - fit.shaftMinimumDiameter;
    fit.fitToleranceWidth = ...
        fit.holeToleranceWidth + fit.shaftToleranceWidth;

    % Worst-case spillerum. Negativt fortegn betyder overlap.
    fit.minimumSignedClearance = ...
        fit.holeMinimumDiameter - fit.shaftMaximumDiameter;
    fit.maximumSignedClearance = ...
        fit.holeMaximumDiameter - fit.shaftMinimumDiameter;

    zeroTolerance = 100 * eps(max(1, max(abs([ ...
        fit.minimumSignedClearance, fit.maximumSignedClearance]))));

    if abs(fit.minimumSignedClearance) <= zeroTolerance
        fit.minimumSignedClearance = 0;
    end
    if abs(fit.maximumSignedClearance) <= zeroTolerance
        fit.maximumSignedClearance = 0;
    end

    % Positive stoerrelser til rapportering.
    fit.minimumClearance = max(fit.minimumSignedClearance, 0);
    fit.maximumClearance = max(fit.maximumSignedClearance, 0);
    fit.minimumInterference = max(-fit.maximumSignedClearance, 0);
    fit.maximumInterference = max(-fit.minimumSignedClearance, 0);

    % Klassifikation.
    if fit.minimumSignedClearance >= 0 && fit.maximumSignedClearance > 0
        fit.classification = "spillerumspasning";
    elseif fit.maximumSignedClearance <= 0 && fit.minimumSignedClearance < 0
        fit.classification = "prespasning";
    elseif fit.minimumSignedClearance < 0 && fit.maximumSignedClearance > 0
        fit.classification = "overgangspasning";
    else
        fit.classification = "linje-til-linje";
    end
end

function runP1RegressionTests()
    fprintf('\n============================================================\n')
    fprintf('OPTIONAL TEST CASES - P1 REGRESSIONSTEST\n')
    fprintf('============================================================\n')

    testCases(1) = struct( ...
        'name', "Kursus: hul 31 JS12 / aksel 35 js12", ...
        'holeNominal', 31, 'shaftNominal', 35, ...
        'holeUpper', 0.125, 'holeLower', -0.125, ...
        'shaftUpper', 0.125, 'shaftLower', -0.125, ...
        'expectedLimits', [30.875, 31.125, 34.875, 35.125], ...
        'expectedClearance', [-4.250, -3.750], ...
        'expectedClassification', "prespasning");

    testCases(2) = struct( ...
        'name', "Kursusvariant: hul 31 JS12 / aksel 31.1 js12", ...
        'holeNominal', 31, 'shaftNominal', 31.1, ...
        'holeUpper', 0.125, 'holeLower', -0.125, ...
        'shaftUpper', 0.125, 'shaftLower', -0.125, ...
        'expectedLimits', [30.875, 31.125, 30.975, 31.225], ...
        'expectedClearance', [-0.350, 0.150], ...
        'expectedClassification', "overgangspasning");

    testCases(3) = struct( ...
        'name', "Haandkontrol: sikkert spillerum", ...
        'holeNominal', 50, 'shaftNominal', 50, ...
        'holeUpper', 0.025, 'holeLower', 0.000, ...
        'shaftUpper', -0.010, 'shaftLower', -0.025, ...
        'expectedLimits', [50.000, 50.025, 49.975, 49.990], ...
        'expectedClearance', [0.010, 0.050], ...
        'expectedClassification', "spillerumspasning");

    testCases(4) = struct( ...
        'name', "Randtilfaelde: eksakt linje-til-linje", ...
        'holeNominal', 20, 'shaftNominal', 20, ...
        'holeUpper', 0, 'holeLower', 0, ...
        'shaftUpper', 0, 'shaftLower', 0, ...
        'expectedLimits', [20, 20, 20, 20], ...
        'expectedClearance', [0, 0], ...
        'expectedClassification', "linje-til-linje");

    testTolerance = 1e-12;

    for testIndex = 1:numel(testCases)
        test = testCases(testIndex);

        fit = calculateP1Fit( ...
            test.holeNominal, test.shaftNominal, ...
            test.holeUpper, test.holeLower, ...
            test.shaftUpper, test.shaftLower);

        actualLimits = [fit.holeMinimumDiameter, ...
            fit.holeMaximumDiameter, fit.shaftMinimumDiameter, ...
            fit.shaftMaximumDiameter];
        actualClearance = [fit.minimumSignedClearance, ...
            fit.maximumSignedClearance];

        assert(all(abs(actualLimits - test.expectedLimits) <= testTolerance), ...
            'Graensemaal fejlede i test: %s', char(test.name));
        assert(all(abs(actualClearance - test.expectedClearance) <= testTolerance), ...
            'Spillerum/overlap fejlede i test: %s', char(test.name));
        assert(strcmpi(fit.classification, test.expectedClassification), ...
            'Klassifikation fejlede i test: %s', char(test.name));

        fprintf('OK: %s\n', char(test.name))
    end

    fprintf('Alle %d regressionstest bestod.\n', numel(testCases))
end
