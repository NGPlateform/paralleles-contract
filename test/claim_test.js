// 定义合约实例
let meshManagementInstance

// 初始化Web3和合约实例
// 初始化Web3和合约实例
async function init() {
    // 检查是否有MetaMask注入的Web3实例
    if (typeof window.ethereum !== 'undefined') {
        const web3 = new Web3(window.ethereum)

        // 请求MetaMask连接
        await window.ethereum.request({method: 'eth_requestAccounts'})

        // 请替换为MeshManagement合约的ABI
        const meshManagementABI = [
            {
                inputs: [
                    {
                        internalType: 'address',
                        name: '_area1',
                        type: 'address',
                    },
                    {
                        internalType: 'address',
                        name: '_area2',
                        type: 'address',
                    },
                    {
                        internalType: 'address',
                        name: '_area3',
                        type: 'address',
                    },
                    {
                        internalType: 'address',
                        name: '_area4',
                        type: 'address',
                    },
                    {
                        internalType: 'address',
                        name: '_multiClaim',
                        type: 'address',
                    },
                ],
                stateMutability: 'nonpayable',
                type: 'constructor',
            },
            {
                inputs: [],
                name: 'area1',
                outputs: [
                    {
                        internalType: 'contract MeshArea1',
                        name: '',
                        type: 'address',
                    },
                ],
                stateMutability: 'view',
                type: 'function',
            },
            {
                inputs: [],
                name: 'area2',
                outputs: [
                    {
                        internalType: 'contract MeshArea2',
                        name: '',
                        type: 'address',
                    },
                ],
                stateMutability: 'view',
                type: 'function',
            },
            {
                inputs: [],
                name: 'area3',
                outputs: [
                    {
                        internalType: 'contract MeshArea3',
                        name: '',
                        type: 'address',
                    },
                ],
                stateMutability: 'view',
                type: 'function',
            },
            {
                inputs: [],
                name: 'area4',
                outputs: [
                    {
                        internalType: 'contract MeshArea4',
                        name: '',
                        type: 'address',
                    },
                ],
                stateMutability: 'view',
                type: 'function',
            },
            {
                inputs: [
                    {
                        internalType: 'int256',
                        name: 'lat',
                        type: 'int256',
                    },
                    {
                        internalType: 'int256',
                        name: 'lon',
                        type: 'int256',
                    },
                ],
                name: 'claim',
                outputs: [],
                stateMutability: 'nonpayable',
                type: 'function',
            },
            {
                inputs: [
                    {
                        internalType: 'int256',
                        name: 'lat',
                        type: 'int256',
                    },
                    {
                        internalType: 'int256',
                        name: 'lon',
                        type: 'int256',
                    },
                ],
                name: 'getClaimCount',
                outputs: [
                    {
                        internalType: 'uint8',
                        name: '',
                        type: 'uint8',
                    },
                ],
                stateMutability: 'view',
                type: 'function',
            },
            {
                inputs: [],
                name: 'multiClaim',
                outputs: [
                    {
                        internalType: 'contract MultiClaim',
                        name: '',
                        type: 'address',
                    },
                ],
                stateMutability: 'view',
                type: 'function',
            },
        ]

        // 请替换为MeshManagement合约的地址
        const meshManagementAddress =
            '0xA24fdFCE32a56865e092343A59075a134CeB3265'

        meshManagementInstance = new web3.eth.Contract(
            meshManagementABI,
            meshManagementAddress
        )
    } else {
        console.error('MetaMask is not installed!')
    }
}

// 随机生成经纬度
function getRandomLatLon() {
    const lat = Math.floor(Math.random() * 18000) - 9000 // -9000 to 8999
    const lon = Math.floor(Math.random() * 36000) - 18000 // -18000 to 17999
    return {lat, lon}
}

// 测试MeshManagement的claim函数
async function testClaim(lat, lon) {
    try {
        // 请替换为您的账户地址
        const fromAddress = '0x43991d26c66d30197C249ffDd0f5Bf305a36dc07'

        for (let i = 0; i < 10; i++) {
            // 调用MeshManagement的claim函数
            const result = await meshManagementInstance.methods
                .claim(lat, lon)
                .send({from: fromAddress})
            console.log(
                `Transaction successful for lat: ${lat}, lon: ${lon} - Attempt: ${
                    i + 1
                }`,
                result
            )

            // 检查getClaimCount的结果
            const claimCount = await meshManagementInstance.methods
                .getClaimCount(lat, lon)
                .call()
            if (claimCount !== i + 1) {
                console.error(
                    `Error: Expected claim count to be ${
                        i + 1
                    } but got ${claimCount} for lat: ${lat}, lon: ${lon}`
                )
            } else {
                console.log(
                    `Claim count is correct for lat: ${lat}, lon: ${lon}`
                )
            }
        }
    } catch (error) {
        console.error(`Error calling claim for lat: ${lat}, lon: ${lon}`, error)
    }
}

// 初始化并测试
async function runTests() {
    await init()

    for (let i = 0; i < 10; i++) {
        const {lat, lon} = getRandomLatLon()
        await testClaim(lat, lon)
    }
}

runTests()
