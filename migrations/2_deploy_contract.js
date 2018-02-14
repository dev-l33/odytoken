var token = artifacts.require("ODYToken");

module.exports = function(deployer) {
    deployer.deploy(token,
        "0xf17f52151EbEF6C7334FAD080c5704D77216b732",
        "0xC5fdf4076b8F3A5357c5E395ab970B5B54098Fef",
        "0x821aEa9a577a9b44299B9c15c88cf3087F3b5544",
        "0x0d1d4e623D10F9FBA5Db95830F7d3839406C6AF2",
        "0x2932b7A2355D6fecc4b5c0B6BD44cC31df247a2e"
    );
};