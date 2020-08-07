module React.Basic.Hooks.Aff
  ( useAff
  , UseAff
  , useAffReducer
  , AffReducer
  , mkAffReducer
  , runAffReducer
  , noEffects
  , UseAffReducer
  ) where

import Prelude
import Data.Either (Either(..))
import Data.Foldable (for_)
import Data.Function.Uncurried (Fn2, mkFn2, runFn2)
import Data.Maybe (Maybe(..))
import Data.Newtype (class Newtype)
import Effect (Effect)
import Effect.Aff (Aff, Error, error, killFiber, launchAff, launchAff_, throwError, try)
import Effect.Class (liftEffect)
import Effect.Unsafe (unsafePerformEffect)
import React.Basic.Hooks (type (/\), Hook, Reducer, UnsafeReference(..), UseEffect, UseMemo, UseReducer, UseState, coerceHook, mkReducer, unsafeRenderEffect, useEffect, useMemo, useReducer, useState, (/\))
import React.Basic.Hooks as React

-- | `useAff` is used for asynchronous effects or `Aff`. The asynchronous effect
-- | is re-run whenever the deps change. If another `Aff` runs when the deps
-- | change before the previous async resolves, it will cancel the previous
-- | in-flight effect.
-- |
-- | *Note: This hook requires parent components to handle error states! Don't
-- |   forget to implement a React error boundary or avoid `Aff` errors entirely
-- |   by incorporating them into your result type!*
useAff ::
  forall deps a.
  Eq deps =>
  deps ->
  Aff a ->
  Hook (UseAff deps a) (Maybe a)
useAff deps aff =
  coerceHook React.do
    result /\ setResult <- useState Nothing
    useEffect deps do
      setResult (const Nothing)
      fiber <-
        launchAff do
          r <- try aff
          liftEffect do
            setResult \_ -> Just r
      pure do
        launchAff_ do
          killFiber (error "Stale request cancelled") fiber
    unsafeRenderEffect case result of
      Just (Left err) -> throwError err
      Just (Right a) -> pure (Just a)
      Nothing -> pure Nothing

newtype UseAff deps a hooks
  = UseAff (UseEffect deps (UseState (Maybe (Either Error a)) hooks))

derive instance ntUseAff :: Newtype (UseAff deps a hooks) _

-- | Provide an initial state and a reducer function. This is a more powerful
-- | version of `useReducer`, where a state change can additionally queue
-- | asynchronous operations. The results of those operations must be  mapped
-- | into the reducer's `action` type. This is essentially the Elm architecture.
-- |
-- | Generally, I recommend `useAff` paired with tools like `useResetToken` over
-- | `useAffReducer` as there are many ways `useAffReducer` can result in race
-- | conditions. `useAff` with proper dependency management will handle previous
-- | request cancellation and ensure your `Aff` result is always in sync with
-- | the provided `deps`, for example. To accomplish the same thing with
-- | `useAffReducer` would require tracking `Fiber`s manually in your state
-- | somehow.. :c
-- |
-- | That said, `useAffReducer` can still be helpful when converting from the
-- | current `React.Basic` (non-hooks) API or for those used to Elm.
-- |
-- | *Note: Aff failures are thrown. If you need to capture an error state, be
-- |   sure to capture it in your action type!*
useAffReducer ::
  forall state action.
  state ->
  AffReducer state action ->
  Hook (UseAffReducer state action) (state /\ (action -> Effect Unit))
useAffReducer initialState affReducer =
  coerceHook React.do
    reducer' <-
      useMemo (UnsafeReference affReducer) \_ ->
        unsafePerformEffect do
          mkReducer (\{ state } -> runAffReducer affReducer state)
    { state, effects } /\ dispatch <-
      useReducer { state: initialState, effects: [] } reducer'
    useEffect (UnsafeReference effects) do
      for_ effects \aff ->
        launchAff_ do
          actions <- aff
          liftEffect do for_ actions dispatch
      mempty
    pure (state /\ dispatch)

newtype AffReducer state action
  = AffReducer
  ( Fn2
      state
      action
      { state :: state, effects :: Array (Aff (Array action)) }
  )

mkAffReducer ::
  forall state action.
  (state -> action -> { state :: state, effects :: Array (Aff (Array action)) }) ->
  Effect (AffReducer state action)
mkAffReducer = pure <<< AffReducer <<< mkFn2

-- | Run a wrapped `Reducer` function as a normal function (like `runFn2`).
-- | Useful for testing, simulating actions, or building more complicated
-- | hooks on top of `useReducer`
runAffReducer ::
  forall state action.
  AffReducer state action ->
  state ->
  action ->
  { state :: state, effects :: Array (Aff (Array action)) }
runAffReducer (AffReducer reducer) = runFn2 reducer

noEffects ::
  forall state action.
  state ->
  { state :: state
  , effects :: Array (Aff (Array action))
  }
noEffects state = { state, effects: [] }

newtype UseAffReducer state action hooks
  = UseAffReducer
  ( UseEffect (UnsafeReference (Array (Aff (Array action))))
      ( UseReducer { state :: state, effects :: Array (Aff (Array action)) } action
          ( UseMemo
              (UnsafeReference (AffReducer state action))
              ( Reducer
                  { effects :: Array (Aff (Array action))
                  , state :: state
                  }
                  action
              )
              hooks
          )
      )
  )

derive instance ntUseAffReducer :: Newtype (UseAffReducer state action hooks) _