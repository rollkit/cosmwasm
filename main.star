# This Kurtosis package spins up a minimal CosmWasm rollup that connects to a DA node
#
# NOTE: currently this is only connecting to a local DA node

da_node = import_module("github.com/rollkit/local-da/main.star@v0.3.0")

def run(plan):
    ##########
    # DA
    ##########

    da_address = da_node.run(
        plan,
    )
    plan.print("connecting to da layer via {0}".format(da_address))

    #################
    # CosmWasm Rollup
    #################
    plan.print("Adding CosmWasm service")
    rpc_port_number = 36657
    grpc_port_number = 9290
    p2p_port_number = 36656
    wasmd_start_cmd = [
        "wasmd",
        "start",
        "--rollkit.aggregator",
        "--rollkit.da_address {0}".format(da_address),
        "--rpc.laddr tcp://127.0.0.1:{0}".format(rpc_port_number),
        "--grpc.address 127.0.0.1:{0}".format(grpc_port_number),
        "--p2p.laddr 0.0.0.0:{0}".format(p2p_port_number),
        "--minimum-gas-prices='0.025uwasm'",
    ]
    wasmd_ports = {
        "rpc-laddr": defaultPortSpec(rpc_port_number),
        # "grpc-addr": defaultPortSpec(grpc_port_number),
        # "p2p-laddr": defaultPortSpec(p2p_port_number),
    }
    wasm = plan.add_service(
        name="wasm",
        config=ServiceConfig(
            # Using CosmWasm version v0.1.0
            # image="ghcr.io/rollkit/cosmwasm:xxxxx",
            image = ImageBuildSpec(
                image_name="cosmwasm",
                build_context_dir=".",
            ),
            cmd=["/bin/sh", "-c", " ".join(wasmd_start_cmd)],
            ports=wasmd_ports,
            public_ports=wasmd_ports,
            ready_conditions=ReadyCondition(
                recipe=ExecRecipe(
                    command=["wasmd", "status", "-n tcp://localhost:{0}".format(rpc_port_number)],
                    extract={
                        "output": "fromjson | .node_info.network",
                    },
                ),
                field="extract.output",
                assertion="==",
                target_value="localwasm",
                interval="1s",
                timeout="1m",
            ),
        ),
    )

    wasm_address = "http://{0}:{1}".format(
        wasm.ip_address, wasm.ports["rpc-laddr"].number
    )
    plan.print("CosmWasm service is available at {0}".format(wasm_address))

def defaultPortSpec(port_number):
    return PortSpec(
        number=port_number,
        transport_protocol="TCP",
        application_protocol="http",
    )
