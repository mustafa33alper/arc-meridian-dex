// Bu script tum Arc DEX kontratlarini sirasiyla deploy eder:
// ArcFactory -> ArcRouter -> 2 adet TestToken
// Calistirmak icin: npm run deploy

const hre = require("hardhat");

async function main() {
  const [deployer] = await hre.ethers.getSigners();
  console.log("Deploy eden cuzdan:", deployer.address);

  const balance = await hre.ethers.provider.getBalance(deployer.address);
  console.log("Cuzdan bakiyesi (USDC gas):", hre.ethers.formatEther(balance));

  console.log("\n1/4 - ArcFactory deploy ediliyor...");
  const Factory = await hre.ethers.getContractFactory("ArcFactory");
  const factory = await Factory.deploy();
  await factory.waitForDeployment();
  console.log("   ArcFactory adresi:", await factory.getAddress());

  console.log("\n2/4 - ArcRouter deploy ediliyor...");
  const Router = await hre.ethers.getContractFactory("ArcRouter");
  const router = await Router.deploy(await factory.getAddress());
  await router.waitForDeployment();
  console.log("   ArcRouter adresi:", await router.getAddress());

  console.log("\n3/4 - Test Token A (ARCA) deploy ediliyor...");
  const TestToken = await hre.ethers.getContractFactory("TestToken");
  const tokenA = await TestToken.deploy("Arc Test Coin A", "ARCA", hre.ethers.parseEther("1000000"));
  await tokenA.waitForDeployment();
  console.log("   ARCA adresi:", await tokenA.getAddress());

  console.log("\n4/4 - Test Token B (ARCB) deploy ediliyor...");
  const tokenB = await TestToken.deploy("Arc Test Coin B", "ARCB", hre.ethers.parseEther("1000000"));
  await tokenB.waitForDeployment();
  console.log("   ARCB adresi:", await tokenB.getAddress());

  console.log("\n=====================================================");
  console.log("DEPLOY TAMAMLANDI. Bu adresleri not al:");
  console.log("=====================================================");
  console.log("FACTORY_ADDRESS =", await factory.getAddress());
  console.log("ROUTER_ADDRESS  =", await router.getAddress());
  console.log("ARCA_ADDRESS    =", await tokenA.getAddress());
  console.log("ARCB_ADDRESS    =", await tokenB.getAddress());
  console.log("=====================================================");
  console.log("Simdi index.html'i ac, 'Kontrat Ayarlari' bolumune");
  console.log("FACTORY_ADDRESS ve ROUTER_ADDRESS'i gir, ardindan");
  console.log("Faucet sekmesinden ARCA ve ARCB adreslerini ekle.");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
