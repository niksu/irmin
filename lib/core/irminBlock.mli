(*
 * Copyright (c) 2013-2014 Thomas Gazagnaire <thomas@gazagnaire.org>
 *
 * Permission to use, copy, modify, and distribute this software for any
 * purpose with or without fee is hereby granted, provided that the above
 * copyright notice and this permission notice appear in all copies.
 *
 * THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
 * WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
 * MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
 * ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *)

(** Store structured values: contents, node and commits. *)

type ('key, 'contents) t =
  | Contents of 'contents
  | Node of 'key IrminNode.t
  | Commit of 'key IrminCommit.t
with bin_io, compare, sexp
(** The different kinds of values which can be stored in the
    database. *)

type origin = IrminOrigin.t

module type S = sig

  (** Signature for structured values. *)

  type key
  (** Keys. *)

  type contents
  (** Contents. *)

  include IrminContents.S with type t = (key, contents) t
  (** Base functions over structured values. *)

end

module S (K: IrminKey.S) (C: IrminContents.S): S with type key = K.t
                                                  and type contents = C.t

module String: S with type key = IrminKey.SHA1.t
                  and type contents = IrminContents.String.t
(** String contents, with SHA1 keys. *)

module JSON: S with type key = IrminKey.SHA1.t
                and type contents = IrminContents.JSON.t
(** JSON contents, with SHA1 keys. *)


module type STORE = sig

  (** The block store holds the representation of all the immutable
      values of the system. *)

  type key
  (** Database keys. *)

  type contents
  (** Contents values. *)

  type value =  (key, contents) t
  (** Block values. *)

  type node = key IrminNode.t
  (** Node values. *)

  type commit = key IrminCommit.t
  (** Commit values. *)

  include IrminStore.AO with type key := key and type value := value

  val list: t -> ?depth:int -> key list -> key list Lwt.t
  (** Return the related blocks, with an history depth limit. *)

  module Contents: IrminContents.STORE with type key = key
                                        and type value = contents

  module Node: IrminNode.STORE with type key = key
                                and type contents = contents

  module Commit: IrminCommit.STORE with type key = key

  val contents_t: t -> Contents.t
  (** The handler for the contents database. *)

  val node_t: t -> Node.t
  (** The handler for the node database. *)

  val commit_t: t -> Commit.t
  (** The handler for the commit database. *)

  val merge: t -> key IrminMerge.t
  (** Merge keys of the store together. *)

  module Key: IrminKey.S with type t = key
  (** Base functions over keys. *)

  module Value: S with type key = key and type contents = contents
  (** Base functions over values. *)

  module Graph: IrminGraph.S with type V.t = (key, unit) IrminGraph.vertex

end

module Make
  (K: IrminKey.S)
  (C: IrminContents.S)
  (S: IrminStore.AO with type key = K.t and type value = (K.t, C.t) t)
  : STORE with type key = K.t
           and type contents   = C.t
           and type Contents.t = S.t
           and type Node.t     = S.t * S.t
           and type Commit.t   = (S.t * S.t) * S.t
(** Create a store for structured values. *)

module Mux
  (K: IrminKey.S)
  (C: IrminContents.S)
  (Contents: IrminStore.AO with type key = K.t and type value = C.t)
  (Node    : IrminStore.AO with type key = K.t and type value = K.t IrminNode.t)
  (Commit  : IrminStore.AO with type key = K.t and type value = K.t IrminCommit.t)
  : STORE with type key = K.t
           and type contents   = C.t
           and type Contents.t = Contents.t
           and type Node.t     = Contents.t * Node.t
           and type Commit.t   = (Contents.t * Node.t) * Commit.t
(** Combine multiple stores to create a global store for structured
    values. XXX: discuss about the cost model, ie. the difference
    between Mux and Make. *)

module Rec (S: STORE): IrminContents.S with type t = S.key
(** Interpret the blocks in a block store as storable objects. *)
