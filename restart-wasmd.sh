wasmd start --rollkit.aggregator --rollkit.da_address http://localhost:7980 --rpc.laddr tcp://127.0.0.1:36657 --grpc.address 127.0.0.1:9290 --p2p.laddr "0.0.0.0:36656" --minimum-gas-prices=0.025uwasm
