#!/usr/bin/env bash
# 🅳🅾🆃🅵🅸🅻🅴🆂 (v0.2.452) - Rock Paper Scissors
# Adapted from https://github.com/Ananta-Gupta/Rock-Paper-Scissors

# rps: Function to play Rock Paper Scissors

check() {
  if [ "$1" == "$2" ]; then
    echo "Draw!"
  elif [ "$1" = 1 ] && [ "$2" = 2 ]; then
    echo "You Lose! Paper beats Rock!"
  elif [ "$1" = 2 ] && [ "$2" = 3 ]; then
    echo "You Lose! Scissor beats Paper!"
  elif [ "$1" = 3 ] && [ "$2" = 1 ]; then
    echo "You Lose! Rock beats Scissor!"
  elif [ "$1" != 1 ] && [ "$1" != 2 ] && [ "$1" != 3 ]; then
    echo "Invalid input! You have not entered a valid number"
  else
    echo " ❭ You Win! 👏🏻"
  fi
}

print() {
  echo ""
  echo "┌──────────────────────────────────────┐"
  echo "│                                      │"
  echo "│          Rock, Paper, Scissors       │"
  echo "│                                      │"
  echo "└──────────────────────────────────────┘"
  echo ""
  echo "Enter a choice :"
  echo "1 for Rock"
  echo "2 for Paper"
  echo "3 for Scissor"
  echo ""
}

rps() {

  clr=0
  i=0
  while [ $i != 1 ]; do
    if [ $clr = 0 ]; then
      clr=0
      clear
      print 1
    fi
    read -r ch1
    echo ""

    case $ch1 in
    1)
      echo "You chose rock"
      ;;
    2)
      echo "You chose paper"
      ;;
    3)
      echo "You chose scissor"
      ;;
    esac

    if [ "$ch1" = 0 ] && [ "$ch1" = 3 ]; then
      echo "please choose from 1, 2 or 3."
      clr=1
      continue
    fi

    ch2=$(echo "$RANDOM%3+1" | bc)

    case $ch2 in
    1)
      echo "The computer chose rock"
      ;;
    2)
      echo "The computer chose paper"
      ;;
    3)
      echo "The computer chose scissor"
      ;;
    esac

    check "$ch1" "$ch2"
    echo "To exit press 0"
    echo "To play again press p : "
    read -r ch3
    if [ "$ch3" = p ]; then
      rep=6
      while [ $rep != 0 ]; do
        clear
        print 1
        echo "Starting in $($rep - 1) seconds!!!"
        rep=$($rep - 1)
      done
      continue
    else
      exit
    fi
  done
}
