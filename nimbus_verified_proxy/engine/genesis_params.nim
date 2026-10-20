# nimbus_verified_proxy
# Copyright (c) 2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

import
  stew/[byteutils, io2],
  results,
  eth/common/times,
  beacon_chain/spec/digest,
  beacon_chain/spec/beacon_time,
  beacon_chain/spec/forks,
  beacon_chain/networking/network_metadata

type GenesisParams* = object
  genesisTime*: uint64
  genesisValidatorsRoot*: Eth2Digest
  genesisBlockRoot*: Eth2Digest
  eip2935ForkTime*: Opt[EthTime] # Prague activation (EIP-2935 history contract)

const
  mainnetGenesisValidatorsRoot = Eth2Digest(
    data: hexToByteArray[32](
      "4b363db94e286120d76eb905340fdd4e54bfe9f06bf33ff6cf5ad27f511bfe95"
    )
  )
  sepoliaGenesisValidatorsRoot = Eth2Digest(
    data: hexToByteArray[32](
      "d8ea171f3c94aea21ebc42a1ed61052acf3f9209c00e4efbaaddac09ed9b8078"
    )
  )
  hoodiGenesisValidatorsRoot = Eth2Digest(
    data: hexToByteArray[32](
      "212f13fc4df078b6cb7db228f1c8307566dcecf900867401a92023d7ba99cb5f"
    )
  )
  mainnetGenesisBlockRoot = Eth2Digest(
    data: hexToByteArray[32](
      "d4e56740f876aef8c010b86a40d5f56745a118d0906a34e69aec8c0db1cb8fa3"
    )
  )
  sepoliaGenesisBlockRoot = Eth2Digest(
    data: hexToByteArray[32](
      "25a5cc106eea7138acab33231d7160d69cb777ee0c2c553fcddf5138993e6dd9"
    )
  )
  hoodiGenesisBlockRoot = Eth2Digest(
    data: hexToByteArray[32](
      "bbe312868b376a3001692a646dd2d7d1e4406380dfd86b98aa8a34d1557c971b"
    )
  )

# Absolute unix time of the start of `epoch`, given genesis time and the
# loaded time params. `Opt.none` when the fork is not scheduled
# (`FAR_FUTURE_EPOCH`).
proc forkActivationTime(
    genesisTime: uint64, timeParams: TimeParams, epoch: Epoch
): Opt[EthTime] =
  if epoch == FAR_FUTURE_EPOCH:
    return Opt.none(EthTime)
  let ns = start_beacon_time(start_slot(epoch), timeParams).ns_since_genesis
  Opt.some(EthTime(genesisTime.int64 + ns div 1_000_000_000))

proc genesisParamsForNetwork*(
    network: string, metadata: Eth2NetworkMetadata
): GenesisParams {.raises: [].} =
  case network
  of "sepolia":
    GenesisParams(
      genesisTime: 1655733600'u64,
      genesisValidatorsRoot: sepoliaGenesisValidatorsRoot,
      genesisBlockRoot: sepoliaGenesisBlockRoot,
      eip2935ForkTime: Opt.some(1_741_159_776.EthTime),
    )
  of "hoodi":
    GenesisParams(
      genesisTime: 1742213400'u64,
      genesisValidatorsRoot: hoodiGenesisValidatorsRoot,
      genesisBlockRoot: hoodiGenesisBlockRoot,
      eip2935ForkTime: Opt.some(1_742_999_832.EthTime),
    )
  of "mainnet":
    GenesisParams(
      genesisTime: 1606824023'u64,
      genesisValidatorsRoot: mainnetGenesisValidatorsRoot,
      genesisBlockRoot: mainnetGenesisBlockRoot,
      eip2935ForkTime: Opt.some(1_746_612_311.EthTime),
    )
  else:
    # A directory name (e.g. a fixturenet's testnet-dir): `metadata` is
    # already loaded from its config.yaml (getMetadataForNetwork). Read the
    # genesis state from the same directory's genesis.ssz for genesisTime and
    # genesisValidatorsRoot. genesisBlockRoot stays zero: its only consumer is
    # the P2P light client backend, which this proxy does not use against a
    # beacon REST API. eip2935ForkTime comes from the loaded runtime config's
    # Electra activation epoch (EIP-2935 ships with Prague/Electra).
    doAssert metadata.genesis.kind == UserSuppliedFile,
      "custom network '" & network & "' needs a genesis.ssz next to its config.yaml"
    var raw: seq[byte]
    io2.readFile(metadata.genesis.path, raw).isOkOr:
      raiseAssert "cannot read genesis state '" & metadata.genesis.path & "': " &
        error.ioErrorMsg()
    let state =
      try:
        readSszForkedHashedBeaconState(metadata.cfg, raw)
      except SerializationError as exc:
        raiseAssert "cannot decode genesis state '" & metadata.genesis.path &
          "': " & exc.msg
    GenesisParams(
      genesisTime: state.genesis_time,
      genesisValidatorsRoot: state.genesis_validators_root,
      genesisBlockRoot: default(Eth2Digest),
      eip2935ForkTime: forkActivationTime(
        state.genesis_time, metadata.cfg.timeParams, metadata.cfg.ELECTRA_FORK_EPOCH
      ),
    )
