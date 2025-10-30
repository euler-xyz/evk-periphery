if (process.argv.length < 6) {
    console.log(`
        Usage:
          node calculate-irm-adaptive-curve.js <targetUtilization> <initialIrAtTarget> <minIrAtTarget> <maxIrAtTarget> [curveSteepness] [adjustmentSpeedDays]
        Default values:
          curveSteepness: 4.0
          adjustmentSpeedDays: 7 days
    `);
    process.exit(1);
}

let SCALE = 1e18;
let DAY = 86400;
let YEAR = 365.2425 * DAY;
let targetUtilization = parsePercent(process.argv[2]);
let initialIrAtTarget = parsePercent(process.argv[3]);
let minIrAtTarget = parsePercent(process.argv[4]);
let maxIrAtTarget = parsePercent(process.argv[5]);
let curveSteepness = process.argv.length > 6 ? process.argv[6] : 4;
let adjustmentSpeed = process.argv.length > 7 ? process.argv[7] : 7;

// Validate target utilization is within bounds (0, 1]
if (targetUtilization <= 0 || targetUtilization > 1) {
    throw Error(`Invalid target utilization: ${targetUtilization}. Must be in range (0, 1]`);
}

// Validate initial rate at target is within min/max bounds
if (initialIrAtTarget < minIrAtTarget || initialIrAtTarget > maxIrAtTarget) {
    throw Error(`Initial rate at target (${initialIrAtTarget}) must be between min (${minIrAtTarget}) and max (${maxIrAtTarget})`);
}

// Validate min rate at target bounds (0.1% to 1000% APY)
const minRateBound = 0.001;
const maxRateBound = 10;
if (minIrAtTarget < minRateBound || minIrAtTarget > maxRateBound) {
    throw Error(`Min rate at target (${minIrAtTarget}) must be between ${minRateBound} and ${maxRateBound}`);
}

// Validate max rate at target bounds (0.1% to 1000% APY)
if (maxIrAtTarget < minRateBound || maxIrAtTarget > maxRateBound) {
    throw Error(`Max rate at target (${maxIrAtTarget}) must be between ${minRateBound} and ${maxRateBound}`);
}

// Validate curve steepness bounds (1.01 to 100)
if (curveSteepness < 1.01 || curveSteepness > 100) {
    throw Error(`Curve steepness (${curveSteepness}) must be between 1.01 and 100`);
}

// Validate adjustment speed bounds (2x to 1000x per year)
if (2 * SCALE / (adjustmentSpeed * DAY) < 2e18 / YEAR || 2 * SCALE / (adjustmentSpeed * DAY) > 1000e18 / YEAR) {
    throw Error(`Adjustment speed (${adjustmentSpeed}) must be between 2x and 1000x per year`);
}

let targetUtilizationScaled = BigInt(Math.floor(targetUtilization * SCALE));
let initialIrAtTargetScaled = BigInt(Math.floor(initialIrAtTarget * SCALE / YEAR));
let minIrAtTargetScaled = BigInt(Math.floor(minIrAtTarget * SCALE / YEAR));
let maxIrAtTargetScaled = BigInt(Math.floor(maxIrAtTarget * SCALE / YEAR));
let curveSteepnessScaled = BigInt(Math.floor(curveSteepness * SCALE));
let adjustmentSpeedScaled = BigInt(Math.floor(2 * SCALE / (adjustmentSpeed * DAY)));

console.log(`            // TargetUtilization=${renderPercent(targetUtilization)} APY,  InitialIrAtTarget=${renderPercent(initialIrAtTarget)} APY  MinIrAtTarget=${renderPercent(minIrAtTarget)} APY  MaxIrAtTarget=${renderPercent(maxIrAtTarget)} APY`);
console.log(`            ${targetUtilizationScaled.toString()} ${initialIrAtTargetScaled.toString()} ${minIrAtTargetScaled.toString()} ${maxIrAtTargetScaled.toString()} ${curveSteepnessScaled.toString()} ${adjustmentSpeedScaled.toString()}`);

function parsePercent(p) {
    return parseFloat(p) / 100;
}

function renderPercent(n) {
    return (n * 100).toFixed(2) + '%';
}
