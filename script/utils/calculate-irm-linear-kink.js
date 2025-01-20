if (process.argv.length < 7) {
    console.log(`
        Usage:
          node calculate-irm-linear-kink.js borrow <baseIr> <kinkIr> <maxIr> <kink>
          node calculate-irm-linear-kink.js supply <baseIr> <kinkIr> <maxIr> <kink> <interestFee>
    `);
    process.exit(1);
}

let mode = process.argv[2];
let baseIr = parsePercent(process.argv[3]);
let kinkIr = parsePercent(process.argv[4]);
let maxIr = parsePercent(process.argv[5]);
let kink = parsePercent(process.argv[6]);

if (kink > 1) throw Error(`kink too big: ${kink}`);

if (mode === 'borrow') {
    // Do nothing
} else if (mode === 'supply') {
    if (process.argv.length < 8) throw Error(`must provide interestFee`);
    let interestFee = parsePercent(process.argv[7]);

    kinkIr = kinkIr / (kink * (1 - interestFee));
    maxIr = maxIr / (1 * (1 - interestFee));
} else {
    throw Error(`Unknown mode: ${mode}`);
}

if (kink < 0 || kink > 1) throw(`bad kink`);
if (baseIr > kinkIr) throw(`baseIr > kinkIr`);
if (kinkIr > maxIr) throw(`kinkIr > maxIr`);


let baseIrScaled = scaleIR(baseIr);
let kinkIrScaled = scaleIR(kinkIr);
let maxIrScaled = scaleIR(maxIr);


let kinkScaled = Math.floor(kink * 2**32);

let slope1 = Math.floor((kinkIrScaled - baseIrScaled) / kinkScaled);
let slope2 = Math.floor((maxIrScaled - kinkIrScaled) / (2**32 - kinkScaled));

console.log(`            // Base=${renderPercent(baseIr)} APY,  Kink(${renderPercent(kink)})=${renderPercent(kinkIr)} APY  Max=${renderPercent(maxIr)} APY`);
console.log(`            ${baseIrScaled.toString()}, ${slope1.toString()}, ${slope2.toString()}, ${kinkScaled}`);




function parsePercent(p) {
    return parseFloat(p) / 100;
}

function renderPercent(n) {
    return (n * 100).toFixed(2) + '%';
}

function scaleIR(p) {
    p = Math.log(1 + p);
    return Number(BigInt(Math.floor(p * 1e9)) * (10n**(27n - 9n)) / BigInt(365.2425 * 86400));
}
