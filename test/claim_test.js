const { ethers } = require('ethers');

const PRIVATE_KEY = "25e36df8005e4f3433ecf15506b6d9b32e57d6d8814b186b94163a800c5e8660"; // 请替换为您的私钥
const provider = new ethers.providers.JsonRpcProvider('https://ethereum-goerli.publicnode.com');
const wallet = new ethers.Wallet(PRIVATE_KEY, provider);



let meshManagementInstance;

async function init() {
    const provider = new ethers.providers.JsonRpcProvider('https://ethereum-goerli.publicnode.com');

    const meshManagementABI = [
        {
          inputs: [
            {
              internalType: "address",
              name: "_area1",
              type: "address",
            },
            {
              internalType: "address",
              name: "_area2",
              type: "address",
            },
            {
              internalType: "address",
              name: "_area3",
              type: "address",
            },
            {
              internalType: "address",
              name: "_area4",
              type: "address",
            },
            {
              internalType: "address",
              name: "_multiClaim",
              type: "address",
            },
          ],
          stateMutability: "nonpayable",
          type: "constructor",
        },
        {
          inputs: [],
          name: "area1",
          outputs: [
            {
              internalType: "contract MeshArea1",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "area2",
          outputs: [
            {
              internalType: "contract MeshArea2",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "area3",
          outputs: [
            {
              internalType: "contract MeshArea3",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "area4",
          outputs: [
            {
              internalType: "contract MeshArea4",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "int256",
              name: "lat",
              type: "int256",
            },
            {
              internalType: "int256",
              name: "lon",
              type: "int256",
            },
          ],
          name: "claim",
          outputs: [],
          stateMutability: "nonpayable",
          type: "function",
        },
        {
          inputs: [
            {
              internalType: "int256",
              name: "lat",
              type: "int256",
            },
            {
              internalType: "int256",
              name: "lon",
              type: "int256",
            },
          ],
          name: "getClaimCount",
          outputs: [
            {
              internalType: "uint8",
              name: "",
              type: "uint8",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
        {
          inputs: [],
          name: "multiClaim",
          outputs: [
            {
              internalType: "contract MultiClaim",
              name: "",
              type: "address",
            },
          ],
          stateMutability: "view",
          type: "function",
        },
      ];


    const meshManagementAddress = "0x3015987D8c7d426B0963E5e006Dd21c78d750482";
    meshManagementInstance = new ethers.Contract(meshManagementAddress, meshManagementABI, wallet);

}

function getRandomLatLon() {
    const lat = Math.floor(Math.random() * 18000) - 9000;
    const lon = Math.floor(Math.random() * 36000) - 18000;
    return { lat, lon };
}

async function testClaim(lat, lon) {
    let timings = [];
    let gasUsages = [];

    try {
        for (let i = 0; i < 2; i++) {
            console.log(`===================Start claim test for lat: ${lat}, lon: ${lon} =====================`);
            // 获取claim之前的claimCount
            const initialClaimCount = await meshManagementInstance.getClaimCount(lat, lon);
            console.log(`Initial claim count: ${initialClaimCount}`);

            // 记录开始时间
            const startTime = Date.now();

            // 设置gasLimit并执行claim
            const tx = await meshManagementInstance.claim(lat, lon, { gasLimit: 30000000 }); // 请根据实际情况调整gasLimit的值
            const receipt = await tx.wait();

            // 记录结束时间
            const endTime = Date.now();

            console.log(`Attempt: ${i + 1}`);

            // 显示gas消耗
            const gasUsed = receipt.gasUsed.toString();
            console.log(`Gas: ${gasUsed}`);

            timings.push(endTime - startTime);
            gasUsages.push(gasUsed);

            const claimCount = await meshManagementInstance.getClaimCount(lat, lon);
            if (claimCount !== initialClaimCount + 1) {
                console.error(`Error: Expected claim count to be ${initialClaimCount + 1} but got ${claimCount} for lat: ${lat}, lon: ${lon}`);
            } else {
                console.log(`Claim count is correct for lat: ${lat}, lon: ${lon}`);
            }
        }
    } catch (error) {
        console.error(`Error calling claim for lat: ${lat}, lon: ${lon}`, error);
    }

    return { timings, gasUsages };
}

async function runTests() {
    await init();

    let totalTimings = [0, 0];
    let totalGasUsages = [0, 0];

    for (let i = 0; i < 1; i++) {
        const { lat, lon } = getRandomLatLon();
        const { timings, gasUsages } = await testClaim(lat, lon);

        totalTimings[0] += timings[0];
        totalTimings[1] += timings[1];

        totalGasUsages[0] += parseInt(gasUsages[0]);
        totalGasUsages[1] += parseInt(gasUsages[1]);
    }

    console.log(`Average time for the first call: ${totalTimings[0] / 100}ms`);
    console.log(`Average gas for the first call: ${totalGasUsages[0] / 100}`);

    console.log(`Average time for the second call: ${totalTimings[1] / 100}ms`);
    console.log(`Average gas for the second call: ${totalGasUsages[1] / 100}`);
}

async function area1Tests() {
    await init();

    let totalTimings = [0, 0];
    let totalGasUsages = [0, 0];

    for (let value = 36; value < 9000; value += 9) {
        const lat = value;
        const lon = value;
        const { timings, gasUsages } = await testClaim(lat, lon);

        totalTimings[0] += timings[0];
        //totalTimings[1] += timings[1];

        totalGasUsages[0] += parseInt(gasUsages[0]);
        //totalGasUsages[1] += parseInt(gasUsages[1]);
    }

}

area1Tests();


