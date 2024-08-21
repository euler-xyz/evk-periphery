const fs = require("fs");
const child_process = require("child_process");
const fetch = requireChecked("cross-fetch");
const Diff = requireChecked("diff");



run();

async function run() {
    let coreInfo = JSON.parse(fs.readFileSync(process.argv[2]));

    let seenAddrs = {};

    for (let c of Object.keys(coreInfo)) {
        let addr = coreInfo[c];
        if (seenAddrs[addr.toLowerCase()]) throw Error(`ERROR: Dup address for: ${c} (${addr})`);
        seenAddrs[addr.toLowerCase()] = 1;

        if (c === 'permit2') continue;

        console.log(`Checking ${c} (${addr})`);
        let check = await checkContract(addr);
        console.log(`  -> ${check.ContractName}`);

        if (check.diff !== '') throw Error(`Diff found in contract ${c} (${addr}): ${diff}`);
    }

    console.log("All OK");
}


async function checkContract(addr) {
    if (!process.env.ETHERSCAN_API_KEY) throw(`need ETHERSCAN_API_KEY env variable`);

    //let res1 = JSON.parse(js.readFileSync('verif.json'));
    let data1 = await fetch(`https://api.etherscan.io/api?module=contract&action=getsourcecode&address=${addr}&apikey=${process.env.ETHERSCAN_API_KEY}`);
    let res1 = await data1.json();

    if (res1.status !== "1") throw(`Etherscan error: {JSON.stringify(res1)}`);
    res1 = res1.result[0];
    res1.SourceCode = JSON.parse(res1.SourceCode.substr(1, res1.SourceCode.length - 2));

    let data2 = child_process.execSync(`forge verify-contract ${addr} ${res1.ContractName} --show-standard-json-input`).toString();
    let res2 = JSON.parse(data2);

    let diff = await processDiff(res1.SourceCode, res2);
    return { diff, ContractName: res1.ContractName, };
}


async function processDiff(data1, data2) {
    let patch = '';

    let sourcesSeen = {};

    for (let source of Object.keys(data1.sources)) {
        sourcesSeen[source] = true;

        let file1 = data1.sources[source].content;
        let file2 = (data2.sources[source] || '').content;

        if (file1 === file2) continue;

        patch += Diff.createPatch(source, file1, file2, '', '');
    }

    for (let source of Object.keys(data2.sources)) {
        if (sourcesSeen[source]) continue;

        patch += Diff.createPatch(source, '', data2.sources[source].content, '', '');
    }

    return patch;
}

function requireChecked(pkg) {
    try {
        return require(pkg);
    } catch (e) {
        console.error(`error loading ${pkg}. Run: npm i ${pkg}`);
        process.exit(0);
    }
}
