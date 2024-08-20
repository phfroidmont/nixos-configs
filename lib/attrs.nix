{ lib, ... }:
rec {
  # attrsToList
  attrsToList = attrs: lib.mapAttrsToList (name: value: { inherit name value; }) attrs;

  # mapFilterAttrs ::
  #   (name -> value -> bool)
  #   (name -> value -> { name = any; value = any; })
  #   attrs
  mapFilterAttrs =
    pred: f: attrs:
    lib.filterAttrs pred (lib.mapAttrs' f attrs);

  # Generate an attribute set by mapping a function over a list of values.
  genAttrs' = values: f: lib.listToAttrs (map f values);

  # anyAttrs :: (name -> value -> bool) attrs
  anyAttrs = pred: attrs: lib.any (attr: pred attr.name attr.value) (attrsToList attrs);

  # countAttrs :: (name -> value -> bool) attrs
  countAttrs = pred: attrs: lib.count (attr: pred attr.name attr.value) (attrsToList attrs);
}
