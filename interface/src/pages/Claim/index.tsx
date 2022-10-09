import useAirdrops from "api/useAirdrops";
import { AirdropsQuery } from "generated/graphql";
import useIPFS from "hooks/useIPFS";
import useWeb3 from "hooks/useWeb3";
import React from "react";
import { Link } from "react-router-dom";
import { IpfsFile } from "types/global";
import { injected } from "utils/connectors";
import Parachute from "assets/parachute-coconut.webp";
import { useCocodropContract } from "hooks/useContract";
import useRedemptionExists from "api/useRedemptionExists";

const AirdropCard: React.FC<{ airdrop: ArrayElement<AirdropsQuery["airdrops"]> }> = ({ airdrop }) => {
  const { account } = useWeb3();
  const [file] = useIPFS<IpfsFile>(airdrop.ipfs);
  const contract = useCocodropContract();
  const redemptionExists = useRedemptionExists(airdrop.id, account);

  if (!file) return null;

  return (
    <div className="w-full my-2 p-4 flex border rounded">
      <img src={Parachute} className="w-48 rounded mr-4" />
      <div className="flex flex-col">
        <div>
          <span className="text-sm mr-2">Cocodrop ID</span>
          <strong className="text-lg">{airdrop.airdropId}</strong>
        </div>
        <strong className="text-xl font-display">{file.metadata.title}</strong>
        <strong>{file.metadata.description}</strong>
        {file.metadata.strategy && (
          <div>
            <span className="text-sm mr-2">Strategy</span>
            <strong className="text-lg">{file.metadata.strategy}</strong>
          </div>
        )}

        <br />

        {account && file.merkleTree[account] ? (
          redemptionExists ? (
            <span className="font-display text-blue-500">Already claimed 🌴</span>
          ) : (
            <button
              className="self-start p-2 border rounded font-display"
              onClick={() => {
                if (!contract) return;
                contract
                  .connect(account)
                  .redeem(airdrop.id, file.merkleTree[account].value, file.merkleTree[account].proof);
              }}
            >
              🥥 Claim
            </button>
          )
        ) : (
          <span className="font-display text-slate-500">Not eligible</span>
        )}
      </div>
    </div>
  );
};

const Claim: React.FC = () => {
  const { chainId, activate } = useWeb3();
  const airdrops = useAirdrops();

  return (
    <div className="p-32 w-full flex flex-col items-start">
      <Link to="/create" className="mb-8 font-display text-3xl">
        Create Airdrop
      </Link>
      {!chainId && (
        <button
          className="text-3xl px-2 my-4 border-4 bg-white py-3 rounded-3xl font-display"
          onClick={() => activate(injected)}
        >
          Connect to see airdrops
        </button>
      )}

      <div className="w-full flex flex-col">
        {airdrops ? (
          airdrops.map((airdrop) => <AirdropCard key={airdrop.id} airdrop={airdrop} />)
        ) : (
          <span>No airdrops available</span>
        )}
      </div>
    </div>
  );
};

export default Claim;
