extends RefCounted
## Research values only; durations in 60 Hz ticks, distances in art pixels.
const DATA={
    "energy_bolt":{"motion":{"clip":"cross","release":10,"length":26,"anchor":"hand_near"},"movement":{"speed":0.},"interaction":{"kind":"projectile","first":10,"last":10,"radius":3.5,"speed":3.2,"range":105.},"impact":{"damage":12,"hitstun":15,"blockstun":7,"freeze":3,"push":1.4},"visual":"bolt","lifecycle":{"life":40}},
    "energy_blade":{"motion":{"clip":"cross","release":11,"length":26,"anchor":"hand_far"},"movement":{"speed":0.},"interaction":{"kind":"blade","first":9,"last":15,"radius":2.,"length":17.},"impact":{"damage":16,"hitstun":17,"blockstun":8,"freeze":4,"push":1.8},"visual":"blade","lifecycle":{"life":26}},
    "impact_dash":{"motion":{"clip":"cross","release":11,"length":25,"anchor":"hand_far"},"movement":{"speed":1.85,"first":4,"last":13,"distance":15.},"interaction":{"kind":"hand","first":9,"last":14,"radius":2.},"impact":{"damage":14,"hitstun":16,"blockstun":8,"freeze":4,"push":1.6},"visual":"dash","lifecycle":{"life":25}}
}
static func has_action(id:String)->bool:return DATA.has(id)
static func get_profile(id:String)->Dictionary:return DATA.get(id,{})
