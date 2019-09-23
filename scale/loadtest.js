import { check } from "k6";
import http from "k6/http";

export default function() {
    let payload = JSON.stringify({catalogName: "MercuryFood", productID: "4757660", quantity: null, variantDisplayValue: null});
    var params =  { headers: { "Content-Type": "application/json" } }
    let res = http.post("https://mercury-www.xc9-k8s.rocks/mercury/checkout/cart/add", payload, params);
    check(res, {
        "is status 204": (r) => r.status === 204
    });
};
