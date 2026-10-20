# nimbus_verified_proxy
# Copyright (c) 2025-2026 Status Research & Development GmbH
# Licensed and distributed under either of
#   * MIT license (license terms in the root directory or at https://opensource.org/licenses/MIT).
#   * Apache v2 license (license terms in the root directory or at https://www.apache.org/licenses/LICENSE-2.0).
# at your option. This file may not be copied, modified, or distributed except according to those terms.

{.push raises: [], gcsafe.}

import results, stint, types

func chainIdToNetworkId*(chainId: UInt256): EngineResult[UInt256] =
  if chainId == 1.u256: # mainnet
    ok(1.u256)
  elif chainId == 11155111.u256: # sepolia
    ok(11155111.u256)
  elif chainId == 560048.u256: # hoodi
    ok(560048.u256)
  else:
    # A fixturenet or other custom network can use any chain id (operator,
    # 2026-10-19). Outside mainnet/sepolia/hoodi's historical quirks, a
    # network's id equals its chain id by EIP-155 convention, so treat it
    # that way instead of failing.
    ok(chainId)
