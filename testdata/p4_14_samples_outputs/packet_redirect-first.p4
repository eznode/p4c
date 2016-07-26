struct Version {
    bit<8> major;
    bit<8> minor;
}

const Version P4_VERSION = { 8w1, 8w2 };
error {
    NoError,
    PacketTooShort,
    NoMatch,
    EmptyStack,
    FullStack,
    OverwritingHeader,
    HeaderTooShort
}

extern packet_in {
    void extract<T>(out T hdr);
    void extract<T>(out T variableSizeHeader, in bit<32> variableFieldSizeInBits);
    T lookahead<T>();
    void advance(in bit<32> sizeInBits);
    bit<32> length();
}

extern packet_out {
    void emit<T>(in T hdr);
}

extern void verify(in bool check, in error toSignal);
action NoAction() {
}
match_kind {
    exact,
    ternary,
    lpm
}

const Version v1modelVersion = { 8w0, 8w1 };
match_kind {
    range,
    selector
}

struct standard_metadata_t {
    bit<9>  ingress_port;
    bit<9>  egress_spec;
    bit<9>  egress_port;
    bit<32> clone_spec;
    bit<32> instance_type;
    bit<1>  drop;
    bit<16> recirculate_port;
    bit<32> packet_length;
}

extern Checksum16 {
    bit<16> get<D>(in D data);
}

enum CounterType {
    packets,
    bytes,
    packets_and_bytes
}

extern counter {
    counter(bit<32> size, CounterType type);
    void count(in bit<32> index);
}

extern direct_counter {
    direct_counter(CounterType type);
}

extern meter {
    meter(bit<32> size, CounterType type);
    void execute_meter<T>(in bit<32> index, out T result);
}

extern direct_meter<T> {
    direct_meter(CounterType type);
    void read(out T result);
}

extern register<T> {
    register(bit<32> size);
    void read(out T result, in bit<32> index);
    void write(in bit<32> index, in T value);
}

extern action_profile {
    action_profile(bit<32> size);
}

extern bit<32> random(in bit<5> logRange);
extern void digest<T>(in bit<32> receiver, in T data);
enum HashAlgorithm {
    crc32,
    crc32_custom,
    crc16,
    crc16_custom,
    random,
    identity
}

extern void mark_to_drop();
extern void hash<O, T, D, M>(out O result, in HashAlgorithm algo, in T base, in D data, in M max);
extern action_selector {
    action_selector(HashAlgorithm algorithm, bit<32> size, bit<32> outputWidth);
}

enum CloneType {
    I2E,
    E2E
}

extern void resubmit<T>(in T data);
extern void recirculate<T>(in T data);
extern void clone(in CloneType type, in bit<32> session);
extern void clone3<T>(in CloneType type, in bit<32> session, in T data);
parser Parser<H, M>(packet_in b, out H parsedHdr, inout M meta, inout standard_metadata_t standard_metadata);
control VerifyChecksum<H, M>(in H hdr, inout M meta, inout standard_metadata_t standard_metadata);
control Ingress<H, M>(inout H hdr, inout M meta, inout standard_metadata_t standard_metadata);
control Egress<H, M>(inout H hdr, inout M meta, inout standard_metadata_t standard_metadata);
control ComputeCkecksum<H, M>(inout H hdr, inout M meta, inout standard_metadata_t standard_metadata);
control Deparser<H>(packet_out b, in H hdr);
package V1Switch<H, M>(Parser<H, M> p, VerifyChecksum<H, M> vr, Ingress<H, M> ig, Egress<H, M> eg, ComputeCkecksum<H, M> ck, Deparser<H> dep);
struct intrinsic_metadata_t {
    bit<4>  mcast_grp;
    bit<4>  egress_rid;
    bit<16> mcast_hash;
    bit<32> lf_field_list;
    bit<64> ingress_global_timestamp;
    bit<16> resubmit_flag;
    bit<16> recirculate_flag;
}

struct metaA_t {
    bit<8> f1;
    bit<8> f2;
}

struct metaB_t {
    bit<8> f1;
    bit<8> f2;
}

header hdrA_t {
    bit<8> f1;
    bit<8> f2;
}

struct metadata {
    @name("intrinsic_metadata") 
    intrinsic_metadata_t intrinsic_metadata;
    @name("metaA") 
    metaA_t              metaA;
    @name("metaB") 
    metaB_t              metaB;
}

struct headers {
    @name("hdrA") 
    hdrA_t hdrA;
}

parser ParserImpl(packet_in packet, out headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name("start") state start {
        packet.extract<hdrA_t>(hdr.hdrA);
        transition accept;
    }
}

struct struct_0 {
    standard_metadata_t field;
    metaA_t             field_0;
}

struct struct_1 {
    standard_metadata_t field_1;
    metaA_t             field_2;
}

control egress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name("_nop") action _nop() {
    }
    @name("_recirculate") action _recirculate() {
        recirculate<struct_0>({ standard_metadata, meta.metaA });
    }
    @name("_clone_e2e") action _clone_e2e(bit<8> mirror_id) {
        clone3<struct_1>(CloneType.E2E, (bit<32>)mirror_id, { standard_metadata, meta.metaA });
    }
    @name("t_egress") table t_egress() {
        actions = {
            _nop();
            _recirculate();
            _clone_e2e();
            NoAction();
        }
        key = {
            hdr.hdrA.f1                    : exact;
            standard_metadata.instance_type: ternary;
        }
        size = 128;
        default_action = NoAction();
    }
    apply {
        t_egress.apply();
    }
}

struct struct_2 {
    standard_metadata_t field_3;
    metaA_t             field_4;
}

struct struct_3 {
    standard_metadata_t field_5;
    metaA_t             field_6;
}

control ingress(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    @name("_nop") action _nop() {
    }
    @name("_set_port") action _set_port(bit<9> port) {
        standard_metadata.egress_spec = port;
        meta.metaA.f1 = 8w1;
    }
    @name("_multicast") action _multicast(bit<4> mgrp) {
        meta.intrinsic_metadata.mcast_grp = mgrp;
    }
    @name("_resubmit") action _resubmit() {
        resubmit<struct_2>({ standard_metadata, meta.metaA });
    }
    @name("_clone_i2e") action _clone_i2e(bit<8> mirror_id) {
        clone3<struct_3>(CloneType.I2E, (bit<32>)mirror_id, { standard_metadata, meta.metaA });
    }
    @name("t_ingress_1") table t_ingress_1() {
        actions = {
            _nop();
            _set_port();
            _multicast();
            NoAction();
        }
        key = {
            hdr.hdrA.f1  : exact;
            meta.metaA.f1: exact;
        }
        size = 128;
        default_action = NoAction();
    }
    @name("t_ingress_2") table t_ingress_2() {
        actions = {
            _nop();
            _resubmit();
            _clone_i2e();
            NoAction();
        }
        key = {
            hdr.hdrA.f1                    : exact;
            standard_metadata.instance_type: ternary;
        }
        size = 128;
        default_action = NoAction();
    }
    apply {
        t_ingress_1.apply();
        t_ingress_2.apply();
    }
}

control DeparserImpl(packet_out packet, in headers hdr) {
    apply {
        packet.emit<hdrA_t>(hdr.hdrA);
    }
}

control verifyChecksum(in headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
    }
}

control computeChecksum(inout headers hdr, inout metadata meta, inout standard_metadata_t standard_metadata) {
    apply {
    }
}

V1Switch<headers, metadata>(ParserImpl(), verifyChecksum(), ingress(), egress(), computeChecksum(), DeparserImpl()) main;
